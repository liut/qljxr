import Cocoa
import Quartz
import SwiftUI

class PreviewViewController: NSViewController, QLPreviewingController {

    func preparePreviewOfFile(at url: URL) async throws {
        let result: Result<NSImage, Error>
        do {
            let data = try Data(contentsOf: url)
            let decoded = try decodeJXR(data: data)
            defer { free_jxr_buffer(decoded.pixels) }
            guard let nsImage = makeNSImage(from: decoded) else {
                throw JXRDecodeError.decodeFailed
            }
            result = .success(nsImage)
        } catch {
            result = .failure(error)
        }

        await MainActor.run {
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
        }
    }
}
