# QLJPEGXR — JPEG XR QuickLook Preview for macOS

A macOS QuickLook preview extension for **JPEG XR** (.jxr / .wdp / .hdp) images, with tone-mapped preview support for **HDR** float formats (scRGB 32-bit float / 16-bit half).

## Features

- Spacebar preview for .jxr files (QuickLook)
- Standalone viewer app with File → Open, drag & drop, Cmd+O
- Direct decode for SDR images
- Automatic HDR detection with tone mapping to sRGB
- Metadata bar: resolution, colour format (SDR / HDR float), file size
- Window auto-resizes to fit image dimensions

## Build

```bash
# Requires Xcode 26+ (macOS 26 SDK)

make          # Release build
make run      # Build & launch the viewer app
make deploy   # Build, install to /Applications/, register QuickLook extension
```

A configured `DEVELOPMENT_TEAM` in Xcode is required (the project uses Automatic Code Signing).

## Usage

**Viewer app:**

```bash
make run                         # Open empty window, then File → Open
open -a QLJPEGXR image.jxr       # Open a specific file directly
```

**QuickLook preview:**

Select a .jxr file in Finder and press Space.

Or via the command line:

```bash
qlmanage -p image.jxr
```

## Project structure

```
HostApp/                    # SwiftUI viewer app
JXRPreviewExtension/        # QuickLook preview extension
Shared/                     # Shared decode & render logic
  JXRDecoder.swift          # SDR/HDR decode + tone mapping
  CGImage+PixelBuffer.swift # CGImage / NSImage creation
jxrlib/                     # jxrlib C source + bridge
  jxr_bridge.c/h            # SDR / HDR float decode bridge
```

## HDR tone mapping

HDR images use a **luminance-normalization** strategy:

- Luminance L ≤ 1 (SDR range): left unchanged — original colours preserved
- Luminance L > 1 (HDR highlights): all channels divided by L — preserves R:G:B ratios while compressing luminance to ≤ 1

A pre-computed sRGB gamma LUT encodes the final output.

## License

MIT

## Acknowledgements

- [4creators/jxrlib](https://github.com/4creators/jxrlib) — JPEG XR decoding library
- [SpecialKO/SKIV](https://github.com/SpecialKO/SKIV) — Windows HDR image viewer (reference)
