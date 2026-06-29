import Foundation
import Accelerate

enum JXRDecodeError: Error, CustomStringConvertible {
    case readFailed
    case decodeFailed(Int32)

    var description: String {
        switch self {
        case .readFailed: return "读取文件失败"
        case .decodeFailed(let code):
            switch code {
            case -1: return "解码失败: PKCreateFactory"
            case -2: return "解码失败: PKCreateCodecFactory"
            case -3: return "解码失败: CreateWS_Memory"
            case -4: return "解码失败: PKImageDecode_Create"
            case -5: return "解码失败: Decoder Initialize (文件损坏或格式不支持)"
            case -6: return "解码失败: 无效的图像尺寸"
            case -7: return "解码失败: 内存分配"
            case -8: return "解码失败: FormatConverter Copy"
            case -9: return "解码失败: Direct Copy"
            case -10: return "解码失败: 输出内存分配"
            case -11: return "解码失败: HDR float 解码"
            case -12: return "HDR JPEG XR 暂不支持预览\n请用 XnConvert 等工具转换为 PNG/JPG"
            default: return "解码失败: 未知错误 (\(code))"
            }
        }
    }
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
        guard let baseAddress = ptr.baseAddress else { return -1 }
        return jxr_decode_from_memory(
            baseAddress.assumingMemoryBound(to: UInt8.self),
            data.count, &outPixels, &width, &height, &stride)
    }

    guard result == 0, let pixels = outPixels else {
        throw JXRDecodeError.decodeFailed(result)
    }

    return JXRDecodedImage(pixels: pixels, width: Int(width), height: Int(height), stride: Int(stride))
}

// MARK: - HDR float decode + tonemap

/// Pre-computed LUT: scRGB linear → sRGB u8 via Reinhard + gamma.  4096 entries cover 0..~16.
private let tonemapLUT: [UInt8] = {
    var lut = [UInt8](repeating: 0, count: 4096)
    for i in 0..<4096 {
        let linear = Float(i) / 256.0
        let tonemapped = linear / (linear + 1.0)
        let srgb = tonemapped <= 0.0031308 ? 12.92 * tonemapped : 1.055 * powf(tonemapped, 1.0/2.4) - 0.055
        lut[i] = UInt8(max(0, min(255, srgb * 255.0 + 0.5)))
    }
    return lut
}()

/// Tonemap scRGB linear float RGBA → sRGB BGRA u8.  Uses malloc for CGDataProvider compatibility.
func tonemapHDRToBGRA(floatPixels: UnsafePointer<Float>, width: Int, height: Int, floatStride: Int) -> (pixels: UnsafeMutablePointer<UInt8>, stride: Int) {
    let outStride = ((width * 4 + 15) & ~15)
    let outPixels = malloc(outStride * height)!.assumingMemoryBound(to: UInt8.self)
    let pixelCount = width * height
    let N = vDSP_Length(pixelCount)

    let r = UnsafeMutablePointer<Float>.allocate(capacity: pixelCount)
    let g = UnsafeMutablePointer<Float>.allocate(capacity: pixelCount)
    let b = UnsafeMutablePointer<Float>.allocate(capacity: pixelCount)
    defer { r.deallocate(); g.deallocate(); b.deallocate() }

    for i in 0..<pixelCount { r[i] = floatPixels[i*4]; g[i] = floatPixels[i*4+1]; b[i] = floatPixels[i*4+2] }

    var zero: Float = 0; var hi = Float.greatestFiniteMagnitude
    var scale: Float = 256.0; var lutMax: Float = 4094.999
    for plane in [r, g, b] {
        vDSP_vclip(plane, 1, &zero, &hi, plane, 1, N)
        vDSP_vsmul(plane, 1, &scale, plane, 1, N)
        vDSP_vclip(plane, 1, &zero, &lutMax, plane, 1, N)
    }

    let ri = UnsafeMutablePointer<UInt16>.allocate(capacity: pixelCount)
    let gi = UnsafeMutablePointer<UInt16>.allocate(capacity: pixelCount)
    let bi = UnsafeMutablePointer<UInt16>.allocate(capacity: pixelCount)
    defer { ri.deallocate(); gi.deallocate(); bi.deallocate() }
    vDSP_vfixu16(r, 1, ri, 1, N)
    vDSP_vfixu16(g, 1, gi, 1, N)
    vDSP_vfixu16(b, 1, bi, 1, N)

    let lut = tonemapLUT
    for i in 0..<pixelCount {
        let d = i * 4
        outPixels[d] = lut[Int(bi[i])]; outPixels[d+1] = lut[Int(gi[i])]
        outPixels[d+2] = lut[Int(ri[i])]; outPixels[d+3] = 255
    }

    let padEnd = width * 4
    if padEnd < outStride { memset(outPixels + (height-1) * outStride + padEnd, 0, outStride - padEnd) }

    return (outPixels, outStride)
}

/// Try SDR decode, fall back to HDR with tonemap.
func decodeJXRWithHDRFallback(data: Data) throws -> JXRDecodedImage {
    do { return try decodeJXR(data: data) }
    catch let error as JXRDecodeError {
        if case .decodeFailed(-12) = error { return try decodeJXRHDR(data: data) }
        throw error
    }
}

/// Decode HDR JXR → float → tonemapped BGRA u8.
func decodeJXRHDR(data: Data) throws -> JXRDecodedImage {
    var outFloat: UnsafeMutablePointer<Float>?
    var width: Int32 = 0, height: Int32 = 0, stride: Int32 = 0

    let result = data.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) -> Int32 in
        guard let base = ptr.baseAddress else { return -1 }
        return jxr_decode_float_from_memory(
            base.assumingMemoryBound(to: UInt8.self),
            data.count, &outFloat, &width, &height, &stride)
    }

    guard result == 0, let fp = outFloat else { throw JXRDecodeError.decodeFailed(result) }
    defer { free(fp) }

    let (u8, u8Stride) = tonemapHDRToBGRA(floatPixels: fp, width: Int(width), height: Int(height), floatStride: Int(stride))
    return JXRDecodedImage(pixels: u8, width: Int(width), height: Int(height), stride: u8Stride)
}
