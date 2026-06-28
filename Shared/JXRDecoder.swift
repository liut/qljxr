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
    var width: Int32 = 0
    var height: Int32 = 0
    var stride: Int32 = 0

    let result = data.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) -> Int32 in
        guard let baseAddress = ptr.baseAddress else {
            return -1
        }
        return jxr_decode_from_memory(
            baseAddress.assumingMemoryBound(to: UInt8.self),
            data.count,
            &outPixels,
            &width,
            &height,
            &stride
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
