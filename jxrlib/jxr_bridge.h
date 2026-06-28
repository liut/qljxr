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

#endif /* jxr_bridge_h */
