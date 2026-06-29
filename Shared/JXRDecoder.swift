import Foundation

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
        throw JXRDecodeError.decodeFailed(result)
    }

    return JXRDecodedImage(
        pixels: pixels,
        width: Int(width),
        height: Int(height),
        stride: Int(stride)
    )
}
