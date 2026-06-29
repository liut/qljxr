#include "jxr_bridge.h"
#include <stdlib.h>
#include <string.h>

#define __ANSI__
#define DISABLE_PERF_MEASUREMENT

#include "windowsmediaphoto.h"
#include "JXRGlue.h"

void free_jxr_buffer(void *ptr) { free(ptr); }

int jxr_decode_from_memory(
    const uint8_t *data, size_t len,
    uint8_t **outPixels, int *outWidth, int *outHeight, int *outStride
) {
    PKFactory *pFactory = NULL;
    PKCodecFactory *pCodecFactory = NULL;
    struct WMPStream *pStream = NULL;
    PKImageDecode *pDecoder = NULL;
    PKFormatConverter *pConverter = NULL;
    ERR err;

    if (PKCreateFactory(&pFactory, PK_SDK_VERSION)) return -1;
    if (PKCreateCodecFactory(&pCodecFactory, WMP_SDK_VERSION)) return -2;
    CreateWS_Memory(&pStream, (U8*)data, len);
    if (!pStream) return -3;
    PKImageDecode_Create_WMP(&pDecoder);
    if (!pDecoder) return -4;
    if (pDecoder->Initialize(pDecoder, pStream)) { pDecoder->Release(&pDecoder); return -5; }

    I32 w = 0, h = 0;
    pDecoder->GetSize(pDecoder, &w, &h);
    *outWidth = w; *outHeight = h;

    // HDR/float formats: not yet supported for SDR preview, caller should retry with float decode
    U8 bd = pDecoder->WMP.wmiI.bdBitDepth;
    if (bd == BD_32F || bd == BD_32S || bd == BD_16F || bd == BD_16S) {
        pDecoder->Release(&pDecoder);
        return -12;
    }

    // Standard 8/16-bit: try format converter for proper BGRA output
    if (pCodecFactory->CreateFormatConverter(&pConverter) == 0 && pConverter) {
        if (pConverter->Initialize(pConverter, pDecoder, ".jxr", GUID_PKPixelFormat32bppBGRA) != 0) {
            pConverter->Release(&pConverter);
            pConverter = NULL;
        }
    }

    U32 stride = (U32)((w * 4 + 15) & ~15u);
    U8 *pixels = (U8 *)malloc((size_t)stride * h);
    if (!pixels) {
        if (pConverter) pConverter->Release(&pConverter);
        pDecoder->Release(&pDecoder);
        return -7;
    }

    PKRect rect = {0, 0, w, h};
    if (pConverter) {
        err = pConverter->Copy(pConverter, &rect, pixels, stride);
        pConverter->Release(&pConverter);
    } else {
        pDecoder->guidPixFormat = GUID_PKPixelFormat32bppBGRA;
        err = pDecoder->Copy(pDecoder, &rect, pixels, stride);
    }
    pDecoder->Release(&pDecoder);

    if (err) { free(pixels); return -9; }

    *outPixels = pixels;
    *outStride = (int)stride;
    return 0;
}

int jxr_decode_float_from_memory(
    const uint8_t *data, size_t len,
    float **outPixels, int *outWidth, int *outHeight, int *outStride
) {
    PKFactory *pFactory = NULL;
    PKCodecFactory *pCodecFactory = NULL;
    struct WMPStream *pStream = NULL;
    PKImageDecode *pDecoder = NULL;
    ERR err;

    if (PKCreateFactory(&pFactory, PK_SDK_VERSION)) return -1;
    if (PKCreateCodecFactory(&pCodecFactory, WMP_SDK_VERSION)) return -2;
    CreateWS_Memory(&pStream, (U8*)data, len);
    if (!pStream) return -3;
    PKImageDecode_Create_WMP(&pDecoder);
    if (!pDecoder) return -4;
    if (pDecoder->Initialize(pDecoder, pStream)) { pDecoder->Release(&pDecoder); return -5; }

    I32 w = 0, h = 0;
    pDecoder->GetSize(pDecoder, &w, &h);
    *outWidth = w; *outHeight = h;

    // Verify HDR float format
    U8 bd = pDecoder->WMP.wmiI.bdBitDepth;
    if (bd != BD_32F && bd != BD_32S && bd != BD_16F && bd != BD_16S) {
        pDecoder->Release(&pDecoder);
        return -12; // Not an HDR file
    }

    // Request 128bpp RGBA float. Decoder converts from source format.
    // Alpha channel may be 0 for RGB-only sources (game screenshots).
    pDecoder->guidPixFormat = GUID_PKPixelFormat128bppRGBAFloat;
    U32 stride = (U32)((w * 16 + 15) & ~15u);

    float *pixels = (float *)malloc((size_t)stride * h);
    if (!pixels) { pDecoder->Release(&pDecoder); return -7; }

    PKRect rect = {0, 0, w, h};
    err = pDecoder->Copy(pDecoder, &rect, (U8*)pixels, stride);
    pDecoder->Release(&pDecoder);

    if (err) { free(pixels); return -9; }

    *outPixels = pixels;
    *outStride = (int)stride;
    return 0;
}
