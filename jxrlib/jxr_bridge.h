#ifndef jxr_bridge_h
#define jxr_bridge_h

#include <stdint.h>
#include <stddef.h>

void free_jxr_buffer(void *ptr);

int jxr_decode_from_memory(
    const uint8_t *data,
    size_t len,
    uint8_t **outPixels,
    int *outWidth,
    int *outHeight,
    int *outStride
);

// HDR float decode: returns scRGB linear float pixels (RGBA, 4 x 32-bit float per pixel).
// Decoder converts from source format; alpha may be 0 for RGB-only sources.
// Caller owns *outPixels and must free with free().
int jxr_decode_float_from_memory(
    const uint8_t *data,
    size_t len,
    float **outPixels,
    int *outWidth,
    int *outHeight,
    int *outStride
);

#endif /* jxr_bridge_h */
