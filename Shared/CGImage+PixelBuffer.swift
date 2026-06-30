import CoreGraphics
import AppKit

func makeCGImage(from decoded: JXRDecodedImage) -> CGImage? {
    let bitsPerComponent = 8
    let bitsPerPixel = 32
    let bytesPerRow = decoded.stride

    guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else {
        return nil
    }

    let bitmapInfo = CGBitmapInfo(
        rawValue: CGImageAlphaInfo.premultipliedLast.rawValue
                | CGBitmapInfo.byteOrder32Big.rawValue
    )

    guard let dataProvider = CGDataProvider(
        data: NSData(
            bytesNoCopy: decoded.pixels,
            length: bytesPerRow * decoded.height,
            freeWhenDone: true
        )
    ) else {
        return nil
    }

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
    guard let cgImage = makeCGImage(from: decoded) else {
        return nil
    }
    return NSImage(
        cgImage: cgImage,
        size: NSSize(width: decoded.width, height: decoded.height)
    )
}
