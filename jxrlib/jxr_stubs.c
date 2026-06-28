/* Stub implementations for encoder/transcode symbols that the decoder-only
   build doesn't need at runtime but the linker requires from JXRGlueJxr.c */

#define __ANSI__
#define DISABLE_PERF_MEASUREMENT
#include "windowsmediaphoto.h"
#include "JXRGlue.h"

/* Encoder stubs -- never called during decode-only usage */
Int ImageStrEncEncode(CTXSTRCODEC ctxSC, const CWMImageBufferInfo* pBI) { (void)ctxSC; (void)pBI; return 1; }
Int ImageStrEncInit(CWMImageInfo* pII, CWMIStrCodecParam* pSCP, CTXSTRCODEC* pctxSC) { (void)pII; (void)pSCP; (void)pctxSC; return 1; }
Int ImageStrEncTerm(CTXSTRCODEC ctxSC) { (void)ctxSC; return 1; }

/* Transcode stub */
Int WMPhotoTranscode(struct WMPStream* pStreamDec, struct WMPStream* pStreamEnc, CWMTranscodingParam* pParam) { (void)pStreamDec; (void)pStreamEnc; (void)pParam; return 1; }
