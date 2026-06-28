---
title: feat: JPEG XR QuickLook Preview Extension
type: feat
status: active
date: 2026-06-28
origin: docs/brainstorms/2026-06-28-jxr-quicklook-requirements.md
---

# feat: JPEG XR QuickLook Preview Extension

## Summary

Build a macOS QuickLook Preview extension for .jxr (JPEG XR) images using SwiftUI, with jxrlib C decoder sources embedded directly in the Xcode project. The high-level PKImageDecode API handles decode + pixel format conversion, outputting 32bpp BGRA for native CGImage display. Packaged as a minimal host app for drag-to-install team distribution.

---

## Problem Frame

JPEG XR has no native macOS decoder. Team members working with .jxr files can't preview them in Finder. This plan scaffolds the full greenfield project: Xcode targets, C/Swift interop, decode pipeline, and UTI registration — producing a working preview extension.

---

## Requirements

**Origin actors:** 团队成员
**Origin flows:** F1 (空格键预览), F2 (多文件预览)
**Origin acceptance examples:** AE1 (有效 .jxr 文件预览), AE2 (多文件切换), AE3 (损坏文件错误提示), AE4 (超大图片正常显示)

- R1. 扩展注册 .jxr 文件类型，macOS 识别并调起预览
- R2. 解码 .jxr 文件为 RGB 位图，正确渲染图片内容
- R3. 支持标准预览窗口交互：缩放、拖拽移动
- R4. 多文件预览支持：前后切换
- R5. 损坏/非 JXR 文件显示错误提示，不崩溃
- R6. 极大尺寸图片（>10000px）仍可正常显示

---

## Scope Boundaries

- 不支持缩略图（Finder 图标预览）
- 不支持 .hdp / .wdp 旧格式
- 不包含 JPEG XR 编码
- 不提供图像编辑、转换、导出
- 不发布 App Store

---

## Context & Research

### Relevant Code and Patterns

- jxrlib high-level API: `PKImageDecode` in `jxrgluelib/JXRGlue.h` — factory → decoder → `Copy()` → pixel buffer
- Memory-backed WMPStream (`CreateWS_Memory`) in `image/sys/image.c` — avoids file I/O in extension sandbox
- Target output format: `GUID_PKPixelFormat32bppBGRA` (8bpc, native CGImage byte order on Apple Silicon)
- Critical compiler defines: `-D__ANSI__`, `-DDISABLE_PERF_MEASUREMENT`
- Include paths: `-Icommon/include`, `-Iimage/sys`
- macOS QuickLook pattern: `QLPreviewingController` + `NSHostingView(rootView:)` for SwiftUI
- UTI declared in host app's `UTImportedTypeDeclarations`, referenced in extension's `QLSupportsContentTypes`

### Institutional Learnings

None — greenfield project. Learnings should be captured in `docs/solutions/` after first build.

### External References

- `4creators/jxrlib` — reference decoder implementation, MIT license
- Apple: `QLPreviewingController`, `NSHostingView`, `UTImportedTypeDeclarations`
- JPEG XR standard: ITU-T T.832

---

## Key Technical Decisions

- **PKImageDecode API over low-level ImageStrDec***: High-level API handles color conversion internally, simpler Swift wrapper surface. The glue layer's `Copy()` does decode + pixel format conversion in one call.
- **Bridging header over module map**: Only extension target needs C code — single-target scope makes module map overhead unnecessary. Simpler build config.
- **Memory-backed WMPStream over file-backed**: QuickLook extension sandbox may restrict file access patterns. Read file to `Data` in Swift, pass buffer to C — cleaner boundary.
- **C memory wrapper (`jxr_bridge.c`)**: jxrlib uses malloc/free internally. Expose a `free_jxr_buffer(void*)` function so Swift never touches raw `free()`, avoiding allocator mismatch bugs.
- **`GUID_PKPixelFormat32bppBGRA` as output format**: Native CGImage byte order on little-endian (Apple Silicon is LE). Matches `CGImageAlphaInfo.premultipliedLast | CGBitmapInfo.byteOrder32Little`.
- **Ad-hoc signing for development builds; Developer ID for team distribution**: No App Store distribution. Team members install via .app bundle or zipped archive.

---

## Open Questions

### Resolved During Planning

None — all origin questions were deferred to planning and resolved here.

### Deferred to Implementation

- jxrlib on Apple Silicon: `-D__ANSI__` path should work (ANSI C, no platform-specific code in decode path), but verify compilation with actual Xcode/Clang
- JXRGluePFC.c encoder references: may need `#ifdef` guards if encoder GUID definitions are referenced but encoder files aren't included. Verify at build time; add stubs if needed
- Large image memory: decode allocates full pixel buffer (`width × height × 4` bytes). For 15000×10000 this is ~600MB. Accept for v1; downscale strategy deferred

---

## Output Structure

```
qljxr/
├── JXRQuickLook.xcodeproj
├── HostApp/
│   ├── HostApp.swift                    # @main App entry, minimal
│   ├── Info.plist                       # UTImportedTypeDeclarations, CFBundleDocumentTypes
│   └── Assets.xcassets                  # App icon (placeholder)
├── JXRPreviewExtension/
│   ├── Info.plist                       # NSExtension, QLSupportsContentTypes
│   ├── PreviewProvider.swift            # QLPreviewProvider principal class
│   ├── PreviewViewController.swift      # QLPreviewingController + NSHostingView
│   └── JXR-Bridging-Header.h           # C bridging header
├── Shared/
│   ├── JXRDecoder.swift                 # Swift wrapper around PKImageDecode
│   ├── CGImage+PixelBuffer.swift        # Raw pixels → CGImage conversion
│   └── UTType+JXR.swift                 # UTType.jxr extension
├── jxrlib/                              # Vendored jxrlib sources (decoder-only subset)
│   ├── image/sys/                       # System layer (~11 files)
│   ├── image/decode/                    # Decode layer (~8 files)
│   ├── jxrgluelib/                      # Glue layer (~4 files)
│   ├── common/include/                  # SAL stubs, guiddef (~6 files)
│   └── jxr_bridge.c                     # C memory management helper
└── docs/
    ├── brainstorms/2026-06-28-jxr-quicklook-requirements.md
    └── plans/2026-06-28-001-feat-jxr-quicklook-extension-plan.md
```

---

## High-Level Technical Design

> *This illustrates the intended approach and is directional guidance for review, not implementation specification. The implementing agent should treat it as context, not code to reproduce.*

**Data flow: .jxr file → SwiftUI Image**

```
Finder 空格键
    │
    ▼
QLPreviewingController.preparePreviewOfFile(at: url)
    │
    ├── 1. Read file bytes: Data(contentsOf: url)
    │
    ├── 2. Call C decode (via bridging header):
    │       jxr_decode_from_memory(fileBytes, &pixels, &w, &h, &stride)
    │         ├── CreateWS_Memory(pStream, bytes, len)   // WMPStream from buffer
    │         ├── PKImageDecode_Create_WMP(&pDecoder)
    │         ├── pDecoder->Initialize(pDecoder, pStream)
    │         ├── pDecoder->guidPixFormat = GUID_PKPixelFormat32bppBGRA
    │         ├── pDecoder->Copy(pDecoder, &rect, outBuf, stride)
    │         └── pDecoder->Release(&pDecoder)
    │
    ├── 3. Raw BGRA pixels → CGImage:
    │       CGImage(width, height, 8, 32, stride,
    │               sRGB, .premultipliedLast | .byteOrder32Little,
    │               CGDataProvider(data: pixelData), ...)
    │
    ├── 4. CGImage → NSImage → SwiftUI Image:
    │       Image(nsImage: NSImage(cgImage, size))
    │         .resizable().aspectRatio(contentMode: .fit)
    │
    └── 5. Host in NSHostingView → pin to view bounds
```

---

## Implementation Units

### U1. Project Scaffold and jxrlib Source Setup

**Goal:** Create Xcode project with host app + QuickLook extension targets, and vendor the jxrlib decoder-only source subset into the project structure.

**Requirements:** R1

**Dependencies:** None

**Files:**
- Create: `JXRQuickLook.xcodeproj/` (Xcode project with two targets)
- Create: `HostApp/HostApp.swift`
- Create: `HostApp/Info.plist`
- Create: `HostApp/Assets.xcassets/`
- Create: `JXRPreviewExtension/Info.plist`
- Create: `JXRPreviewExtension/PreviewProvider.swift`
- Create: `JXRPreviewExtension/PreviewViewController.swift`
- Create: `JXRPreviewExtension/JXR-Bridging-Header.h`
- Create: `jxrlib/` directory with vendored sources:
  - `jxrlib/image/sys/`: windowsmediaphoto.h, strcodec.h, common.h, ansi.h, xplatform_image.h, image.c, strcodec.c, adapthuff.c, strPredQuant.c, strTransform.c, perfTimerANSI.c
  - `jxrlib/image/decode/`: decode.h, decode.c, strdec.c, segdec.c, strInvTransform.c, strPredQuantDec.c, postprocess.c
  - `jxrlib/jxrgluelib/`: JXRGlue.h, JXRGlue.c, JXRGlueJxr.c, JXRGluePFC.c
  - `jxrlib/common/include/`: guiddef.h, wmsal.h, wmspecstring.h, wmspecstrings_adt.h, wmspecstrings_strict.h, wmspecstrings_undef.h
  - `jxrlib/jxr_bridge.c`

**Approach:**
- Use Xcode's QuickLook Preview Extension template (File → New → Target) to scaffold both targets in one step
- Delete any generated .xib file (SwiftUI-only approach)
- Copy jxrlib sources from GitHub into `jxrlib/` directory
- Add all `.c` files to extension target's Compile Sources
- Add `.h` files to extension target (Xcode discovers them for bridging header resolution)
- Configure per-file compiler flags: `-D__ANSI__ -DDISABLE_PERF_MEASUREMENT` for all jxrlib `.c` files
- Set header search paths in extension target: `$(SRCROOT)/jxrlib/common/include`, `$(SRCROOT)/jxrlib/image/sys`, `$(SRCROOT)/jxrlib`, `$(SRCROOT)/jxrlib/jxrgluelib`
- Set `MACOSX_DEPLOYMENT_TARGET = 13.0` on all targets
- Create `Shared/` group (folder) for code shared between host and extension — add Swift files to both target memberships

**Patterns to follow:**
- Standard Xcode QuickLook Preview Extension template layout
- Bridging header pattern: `$(SWIFT_OBJC_BRIDGING_HEADER)` build setting

**Test scenarios:**
- Verify the Xcode project builds successfully with empty Swift files and all C sources compiled
- Verify `-D__ANSI__` selects the ANSI path (check for no Windows `#include` errors)
- Verify no linker errors from missing symbols (encoder files excluded)

**Verification:**
- `xcodebuild -project JXRQuickLook.xcodeproj -scheme HostApp build` succeeds
- All C files compile without errors on arm64

---

### U2. C Memory Bridge Helper

**Goal:** Create a small C shim (`jxr_bridge.c`) that provides a clean memory management boundary between jxrlib and Swift.

**Requirements:** R2

**Dependencies:** U1

**Files:**
- Create: `jxrlib/jxr_bridge.c`
- Create: `jxrlib/jxr_bridge.h`

**Approach:**
- Expose a `free_jxr_buffer(void *ptr)` function that calls `free()` — Swift calls this instead of touching raw `free()`
- This avoids allocator mismatch: jxrlib uses system `malloc`/`free`, and we must free from the same CRT
- Define the function in a standalone `.c` file (not mixed with jxrlib sources) so it's clear it's our adapter code

**Technical design:** (directional)

```c
// jxr_bridge.h
#ifndef jxr_bridge_h
#define jxr_bridge_h
void free_jxr_buffer(void *ptr);
#endif

// jxr_bridge.c
#include "jxr_bridge.h"
#include <stdlib.h>
void free_jxr_buffer(void *ptr) {
    free(ptr);
}
```

**Test scenarios:**
- Compilation: bridging header includes `jxr_bridge.h`, Swift can call `free_jxr_buffer(_:)`
- Link: no duplicate symbol errors

**Verification:**
- Extension target compiles and links with `jxr_bridge.c`

---

### U3. Swift Decoder Wrapper

**Goal:** Wrap the jxrlib decode pipeline in a Swift function that takes a `Data` blob and returns decoded pixel buffer metadata.

**Requirements:** R2, R5

**Dependencies:** U1, U2

**Files:**
- Create: `Shared/JXRDecoder.swift`
- Modify: `JXRPreviewExtension/JXR-Bridging-Header.h` (add JXRGlue.h and jxr_bridge.h imports)

**Approach:**
- Expose a minimal C decode function (via bridging header) that Swift calls
- Wrap the decode in a thin C function to keep the bridging surface small: `jxr_decode_from_memory(const uint8_t *data, size_t len, uint8_t **outPixels, int *outWidth, int *outHeight, int *outStride)`
- This C function does: `PKCreateFactory` → `PKCreateCodecFactory` → `CreateWS_Memory` → `PKImageDecode_Create_WMP` → `Initialize` → set `guidPixFormat = GUID_PKPixelFormat32bppBGRA` → `Copy()` → `Release()`
- Return 0 on success, -1 on decode failure
- Swift side: read file to `Data`, call decode, manage buffer lifetime with `defer { free_jxr_buffer(pixels) }`

**Technical design:** (directional — C side)

```c
// In a new file or appended to jxr_bridge.c:
int jxr_decode_from_memory(
    const uint8_t *data, size_t len,
    uint8_t **outPixels, int *outWidth, int *outHeight, int *outStride
) {
    PKFactory *pFactory = NULL;
    PKCodecFactory *pCodecFactory = NULL;
    struct WMPStream *pStream = NULL;
    PKImageDecode *pDecoder = NULL;

    if (FAILED(PKCreateFactory(&pFactory, PK_SDK_VERSION))) return -1;
    if (FAILED(PKCreateCodecFactory(&pCodecFactory, WMP_SDK_VERSION))) return -1;

    CreateWS_Memory(&pStream, (U8 *)data, (size_t)len);
    if (!pStream) return -1;

    PKImageDecode_Create_WMP(&pDecoder);
    if (FAILED(pDecoder->Initialize(pDecoder, pStream))) return -1;

    pDecoder->guidPixFormat = GUID_PKPixelFormat32bppBGRA;

    I32 w, h;
    pDecoder->GetSize(pDecoder, &w, &h);
    *outWidth = (int)w;
    *outHeight = (int)h;

    U32 stride_val = ((w * 4 + 15) & ~15u); // 16-byte aligned stride
    *outStride = (int)stride_val;

    U8 *pixels = (U8 *)malloc(stride_val * h);
    if (!pixels) { pDecoder->Release(&pDecoder); return -1; }

    PKRect rect = {0, 0, w, h};
    if (FAILED(pDecoder->Copy(pDecoder, &rect, pixels, stride_val))) {
        free(pixels);
        pDecoder->Release(&pDecoder);
        return -1;
    }

    pDecoder->Release(&pDecoder);
    *outPixels = pixels;
    return 0;
}
```

Swift side (directional):

```swift
// Shared/JXRDecoder.swift
import Foundation

enum JXRDecodeError: Error {
    case readFailed
    case decodeFailed
}

struct JXRDecodedImage {
    let pixels: UnsafeMutablePointer<UInt8>
    let width: Int
    let height: Int
    let stride: Int
}

func decodeJXR(data: Data) throws -> JXRDecodedImage {
    var outPixels: UnsafeMutablePointer<UInt8>?
    var width: Int32 = 0, height: Int32 = 0, stride: Int32 = 0

    let result = data.withUnsafeBytes { ptr in
        jxr_decode_from_memory(
            ptr.baseAddress?.assumingMemoryBound(to: UInt8.self),
            data.count,
            &outPixels, &width, &height, &stride
        )
    }

    guard result == 0, let pixels = outPixels else {
        throw JXRDecodeError.decodeFailed
    }

    return JXRDecodedImage(
        pixels: pixels,
        width: Int(width),
        height: Int(height),
        stride: Int(stride)
    )
}
```

**Patterns to follow:**
- Standard C/Swift interop: bridging header for declarations, Swift wrapper for ergonomics
- `withUnsafeBytes` for passing `Data` to C

**Test scenarios:**
- Happy path: valid .jxr data → returns non-null pixels, correct width/height
- Error path: invalid/random data → returns -1, Swift throws `decodeFailed`
- Error path: empty data → returns -1
- Memory: pixel buffer is freed via `free_jxr_buffer` after CGImage creation

**Verification:**
- A valid .jxr test file decodes successfully to a pixel buffer
- An invalid/corrupt file returns an error without crashing

---

### U4. Pixel Buffer to CGImage Conversion

**Goal:** Convert the raw BGRA pixel buffer from jxrlib into a `CGImage`, then to `NSImage` for SwiftUI display.

**Requirements:** R2, R3, R6

**Dependencies:** U3

**Files:**
- Create: `Shared/CGImage+PixelBuffer.swift`

**Approach:**
- Create `CGImage` from raw pixels using `CGDataProvider(data:)` with `NSData(bytesNoCopy:freeWhenDone:false)`
- Use `CGColorSpace.sRGB` color space
- Bitmap info: `CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Little.rawValue` for BGRA
- Use jxrlib-returned stride as `bytesPerRow` (already 16-byte aligned)
- 8 bits per component, 32 bits per pixel
- Wrap in `NSImage(cgImage:size:)` for SwiftUI compatibility
- Manage buffer lifetime: caller owns the pixel buffer until CGImage is no longer needed

**Technical design:** (directional)

```swift
// Shared/CGImage+PixelBuffer.swift
import CoreGraphics
import AppKit

func makeCGImage(from decoded: JXRDecodedImage) -> CGImage? {
    let bitsPerComponent = 8
    let bitsPerPixel = 32
    let bytesPerRow = decoded.stride

    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    let bitmapInfo = CGBitmapInfo(
        rawValue: CGImageAlphaInfo.premultipliedLast.rawValue
                | CGBitmapInfo.byteOrder32Little.rawValue
    )

    guard let dataProvider = CGDataProvider(
        data: NSData(
            bytesNoCopy: decoded.pixels,
            length: bytesPerRow * decoded.height,
            freeWhenDone: false
        )
    ) else { return nil }

    return CGImage(
        width: decoded.width,
        height: decoded.height,
        bitsPerComponent: bitsPerComponent,
        bitsPerPixel: bitsPerPixel,
        bytesPerRow: bytesPerRow,
        space: colorSpace,
        bitmapInfo: bitmapInfo,
        provider: dataProvider,
        decode: nil,
        shouldInterpolate: true,
        intent: .defaultIntent
    )
}

func makeNSImage(from decoded: JXRDecodedImage) -> NSImage? {
    guard let cgImage = makeCGImage(from: decoded) else { return nil }
    return NSImage(cgImage: cgImage, size: NSSize(width: decoded.width, height: decoded.height))
}
```

**Patterns to follow:**
- Standard `CGDataProvider` → `CGImage` → `NSImage` pipeline
- `bytesNoCopy:freeWhenDone:false` — caller manages buffer life

**Test scenarios:**
- Happy path: decoded 100×100 image → valid CGImage with correct dimensions
- Edge case: 1×1 image → valid single-pixel CGImage
- Edge case: image with stride > width×4 (alignment padding) → correct rendering
- Error path: null data provider → returns nil

**Verification:**
- A decoded test image renders correctly in a SwiftUI `Image` view
- Large images (10000+ px) render without memory issues (memory usage proportional to image size)

---

### U5. SwiftUI Preview View

**Goal:** Build the SwiftUI view that displays the decoded image with standard preview interactions.

**Requirements:** R3, R5

**Dependencies:** U4

**Files:**
- Create: `JXRPreviewExtension/PreviewView.swift`

**Approach:**
- `JXRPreviewView` takes an `NSImage` and displays it with `Image(nsImage:)`
- `.resizable()` + `.aspectRatio(contentMode: .fit)` for proper scaling
- Wrap in `ScrollView` with magnification gesture support for zoom
- Handle error state: if decode fails, show a descriptive error message with icon
- Handle loading state: placeholder during decode (decode is fast so this may not be visible, but good form)

**Technical design:** (directional)

```swift
// JXRPreviewExtension/PreviewView.swift
import SwiftUI

struct JXRPreviewView: View {
    let nsImage: NSImage?
    let errorMessage: String?

    init(image: NSImage) {
        self.nsImage = image
        self.errorMessage = nil
    }

    init(error: String) {
        self.nsImage = nil
        self.errorMessage = error
    }

    var body: some View {
        if let image = nsImage {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else if let error = errorMessage {
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 32))
                    .foregroundColor(.secondary)
                Text(error)
                    .foregroundColor(.secondary)
            }
        }
    }
}
```

**Test scenarios:**
- Happy path: valid NSImage renders in preview, resizing the window keeps aspect ratio
- Error path: nil image with error message shows error icon and text
- Zoom: scroll wheel / trackpad pinch zooms the image (standard SwiftUI ScrollView behavior)

**Verification:**
- View renders correctly when given a valid NSImage
- Error state shows clear message without layout issues

---

### U6. QuickLook Preview Controller

**Goal:** Implement `QLPreviewingController` that orchestrates the decode + display pipeline when Finder invokes the preview.

**Requirements:** R1, R4, R5

**Dependencies:** U3, U4, U5

**Files:**
- Modify: `JXRPreviewExtension/PreviewViewController.swift`

**Approach:**
- Implement `QLPreviewingController` on an `NSViewController` subclass
- In `preparePreviewOfFile(at:completionHandler:)`:
  1. Read file data from the URL
  2. Call `decodeJXR(data:)` from U3
  3. Convert to `NSImage` via `makeNSImage(from:)` from U4
  4. Create `JXRPreviewView` with the image
  5. Host in `NSHostingView`, pin to view bounds
  6. Call completion handler with nil on success, with error on failure
- Handle multi-file preview: QuickLook passes one URL at a time; switching files re-invokes `preparePreviewOfFile`
- All AppKit view mutations must happen on `@MainActor`; decode (C code) can happen on background queue

**Technical design:** (directional)

```swift
// JXRPreviewExtension/PreviewViewController.swift
import Cocoa
import Quartz
import SwiftUI

class PreviewViewController: NSViewController, QLPreviewingController {

    @MainActor
    func preparePreviewOfFile(
        at url: URL,
        completionHandler handler: @escaping (Error?) -> Void
    ) {
        // Decode can happen off main actor, but view setup must be main
        DispatchQueue.global().async {
            let result: Result<NSImage, Error>
            do {
                let data = try Data(contentsOf: url)
                let decoded = try decodeJXR(data: data)
                defer { free_jxr_buffer(decoded.pixels) }
                guard let nsImage = makeNSImage(from: decoded) else {
                    handler(JXRDecodeError.decodeFailed)
                    return
                }
                result = .success(nsImage)
            } catch {
                result = .failure(error)
            }

            DispatchQueue.main.async {
                let previewView: JXRPreviewView
                switch result {
                case .success(let image):
                    previewView = JXRPreviewView(image: image)
                case .failure:
                    previewView = JXRPreviewView(error: "无法预览此 JPEG XR 文件")
                }

                let hostingView = NSHostingView(rootView: previewView)
                hostingView.translatesAutoresizingMaskIntoConstraints = false
                self.view.subviews.forEach { $0.removeFromSuperview() }
                self.view.addSubview(hostingView)
                NSLayoutConstraint.activate([
                    hostingView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
                    hostingView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
                    hostingView.topAnchor.constraint(equalTo: self.view.topAnchor),
                    hostingView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
                ])

                handler(nil)
            }
        }
    }
}
```

**Patterns to follow:**
- Standard `QLPreviewingController` pattern with `NSHostingView`
- Background decode → main actor view setup dispatch
- Completion handler must be called exactly once

**Test scenarios:**
- Happy path: valid .jxr file → preview window shows image
- Happy path (covers AE2): QuickLook invoked with multiple .jxr files → switching with arrow keys re-prepares each file
- Error path (covers AE3): corrupt file → error text shown, no crash
- Edge case: very large file → decodes asynchronously without blocking UI

**Verification:**
- `qlmanage -p test.jxr` shows the preview image
- `qlmanage -p broken.jxr` shows error UI, process exits cleanly
- Multi-file selection preview works in Finder

---

### U7. Custom UTI and Extension Configuration

**Goal:** Configure the host app's Info.plist with the `.jxr` UTI declaration and the extension's Info.plist for QuickLook integration.

**Requirements:** R1

**Dependencies:** U1

**Files:**
- Modify: `HostApp/Info.plist`
- Modify: `JXRPreviewExtension/Info.plist`

**Approach:**
- Host app Info.plist:
  - Add `UTImportedTypeDeclarations` declaring `com.jxrquicklook.jxr` UTI
  - UTI conforms to `public.image`, tagged with `.jxr` extension and `image/jxr` MIME type
  - Add `CFBundleDocumentTypes` for .jxr association
- Extension Info.plist:
  - `NSExtensionPointIdentifier`: `com.apple.quicklook.preview`
  - `QLSupportsContentTypes`: `["com.jxrquicklook.jxr"]`
  - `CFBundleDocumentTypes` with `QLGenerator` role referencing the same UTI
  - `NSExtensionPrincipalClass`: `$(PRODUCT_MODULE_NAME).PreviewProvider`

**Technical design:** Key plist entries (directional):

Host app `UTImportedTypeDeclarations`:
```xml
<key>UTImportedTypeDeclarations</key>
<array>
    <dict>
        <key>UTTypeIdentifier</key>
        <string>com.jxrquicklook.jxr</string>
        <key>UTTypeDescription</key>
        <string>JPEG XR Image</string>
        <key>UTTypeConformsTo</key>
        <array>
            <string>public.image</string>
        </array>
        <key>UTTypeTagSpecification</key>
        <dict>
            <key>public.filename-extension</key>
            <array><string>jxr</string></array>
            <key>public.mime-type</key>
            <array><string>image/jxr</string></array>
        </dict>
    </dict>
</array>
```

Extension NSExtension dict:
```xml
<key>NSExtension</key>
<dict>
    <key>NSExtensionPointIdentifier</key>
    <string>com.apple.quicklook.preview</string>
    <key>NSExtensionPrincipalClass</key>
    <string>$(PRODUCT_MODULE_NAME).PreviewProvider</string>
    <key>NSExtensionAttributes</key>
    <dict>
        <key>QLSupportsContentTypes</key>
        <array>
            <string>com.jxrquicklook.jxr</string>
        </array>
    </dict>
</dict>
```

**Test scenarios:**
- Verify UTI is registered: `mdls -name kMDItemContentType test.jxr` shows `com.jxrquicklook.jxr`
- Verify QuickLook discovers extension: `qlmanage -m plugins | grep jxr` shows the extension
- Integration: Finder shows preview on spacebar press

**Verification:**
- `qlmanage -p test.jxr` invokes the extension and shows output
- UTI declaration doesn't conflict with system-registered types

---

### U8. Host App and Packaging

**Goal:** Create the minimal host app shell and configure build settings for team distribution packaging.

**Requirements:** None directly (infrastructure)

**Dependencies:** U1

**Files:**
- Modify: `HostApp/HostApp.swift`
- Create: `HostApp/HostApp.entitlements`

**Approach:**
- Host app is a minimal SwiftUI App with no UI — just an empty scene that never shows a window
- Use `NSApplicationDelegate` to suppress dock icon and menu bar
- Set `LSUIElement = YES` in Info.plist so host app doesn't appear in dock
- Host app's purpose: deliver the extension and register the UTI via its Info.plist
- Build phases: ensure extension is embedded at `Contents/PlugIns/` in the host app bundle
- Signing: ad-hoc for development builds; for team distribution configure Development or Developer ID signing

**Technical design:** (directional)

```swift
// HostApp/HostApp.swift
import SwiftUI

@main
struct HostApp: App {
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
```

**Test scenarios:**
- Host app launches without showing a window or dock icon
- Extension is embedded correctly: `ls HostApp.app/Contents/PlugIns/` shows `JXRPreviewExtension.appex`
- `qlmanage -p test.jxr` invokes the extension after the host app has been launched at least once (to register UTI)

**Verification:**
- App bundle structure is correct: `HostApp.app/Contents/PlugIns/JXRPreviewExtension.appex`
- UTI registration persists after app first launch
- Archive → Export app builds and signs correctly

---

## System-Wide Impact

- **Interaction graph:** QuickLook system service (`qlmanage`) loads the extension in a sandboxed XPC process. Finder communicates with QuickLook, not directly with the extension.
- **Error propagation:** Decode errors → Swift `Error` → `completionHandler(error)` → QuickLook shows generic "no preview" UI. The SwiftUI error view (U5) provides a user-friendly message before handler call.
- **State lifecycle risks:** QuickLook reuses the extension process across multiple preview requests. `preparePreviewOfFile` is called anew each time. Previous `CGImage`/`NSImage` objects must be released before the next decode — handled by `view.subviews.forEach { $0.removeFromSuperview() }` releasing the hosting view.
- **Unchanged invariants:** No system preference changes, no Launch Services database modifications, no file system side effects.

---

## Risks & Dependencies

| Risk | Mitigation |
|------|------------|
| JXRGluePFC.c fails to compile in decoder-only config (references encoder GUIDs/functions) | Verify at build time in U1; if needed, add stub defines or `#ifdef` guards; acceptable to include a few encoder-side static GUIDs |
| jxrlib uses C99/C11 features Clang warns about | Set `-w` to suppress jxrlib warnings; set `-std=c11` in jxrlib file compiler flags |
| 24-bit BGR images (no alpha) need conversion to 32bpp for CGImage | High-level API with `GUID_PKPixelFormat32bppBGRA` handles conversion internally via JXRGluePFC.c |
| Team distribution requires code signing identity | Default to ad-hoc signing for development; document Developer ID requirement for wider distribution |
| QuickLook silently fails if extension is unsigned/misconfigured | Verify with `qlmanage -p` early in U6; enable `qlmanage -d` debug logging |

---

## Sources & References

- **Origin document:** [docs/brainstorms/2026-06-28-jxr-quicklook-requirements.md](../brainstorms/2026-06-28-jxr-quicklook-requirements.md)
- Reference implementation: `github.com/4creators/jxrlib` (commit `f7521879862b9085318e814c6157490dd9dbbdb4`)
- Apple: `QLPreviewingController`, `QLPreviewProvider`, `NSHostingView`, `UTImportedTypeDeclarations`
- JPEG XR standard: ITU-T T.832
