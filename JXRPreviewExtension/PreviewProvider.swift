import Quartz
import AppKit
import UniformTypeIdentifiers

class PreviewProvider: QLPreviewProvider, QLPreviewingController {

    func providePreview(for request: QLFilePreviewRequest) async throws -> QLPreviewReply {
        let data = try Data(contentsOf: request.fileURL)
        let decoded = try decodeJXR(data: data)
        defer { free_jxr_buffer(decoded.pixels) }

        guard let cgImage = makeCGImage(from: decoded) else {
            throw JXRDecodeError.decodeFailed
        }

        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
        guard let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
            throw JXRDecodeError.decodeFailed
        }

        return QLPreviewReply(data: pngData, contentType: .png)
    }
}
