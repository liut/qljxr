#include "jxr_bridge.h"
#include <stdlib.h>
#include <string.h>

#define __ANSI__
#define DISABLE_PERF_MEASUREMENT

#include "windowsmediaphoto.h"
#include "JXRGlue.h"

void free_jxr_buffer(void *ptr) {
    free(ptr);
}

int jxr_decode_from_memory(
    const uint8_t *data,
    size_t len,
    uint8_t **outPixels,
    int *outWidth,
    int *outHeight,
    int *outStride
) {
    PKFactory *pFactory = NULL;
    PKCodecFactory *pCodecFactory = NULL;
    struct WMPStream *pStream = NULL;
    PKImageDecode *pDecoder = NULL;
    ERR err;

    err = PKCreateFactory(&pFactory, PK_SDK_VERSION);
    if (err != 0) return -1;

    err = PKCreateCodecFactory(&pCodecFactory, WMP_SDK_VERSION);
    if (err != 0) return -1;

    CreateWS_Memory(&pStream, (U8 *)data, (size_t)len);
    if (!pStream) return -1;

    PKImageDecode_Create_WMP(&pDecoder);
    if (!pDecoder) return -1;

    err = pDecoder->Initialize(pDecoder, pStream);
    if (err != 0) {
        pDecoder->Release(&pDecoder);
        return -1;
    }

    pDecoder->guidPixFormat = GUID_PKPixelFormat32bppBGRA;

    I32 w = 0, h = 0;
    pDecoder->GetSize(pDecoder, &w, &h);
    if (w <= 0 || h <= 0) {
        pDecoder->Release(&pDecoder);
        return -1;
    }

    *outWidth = (int)w;
    *outHeight = (int)h;

    U32 stride_val = (U32)(((w * 4) + 15) & ~15u);
    *outStride = (int)stride_val;

    U8 *pixels = (U8 *)malloc(stride_val * h);
    if (!pixels) {
        pDecoder->Release(&pDecoder);
        return -1;
    }

    PKRect rect = {0, 0, w, h};
    err = pDecoder->Copy(pDecoder, &rect, pixels, stride_val);
    if (err != 0) {
        free(pixels);
        pDecoder->Release(&pDecoder);
        return -1;
    }

    pDecoder->Release(&pDecoder);
    *outPixels = pixels;
    return 0;
}
