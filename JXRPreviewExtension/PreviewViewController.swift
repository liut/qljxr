import Cocoa
import Quartz
import SwiftUI

class PreviewViewController: NSViewController, QLPreviewingController {

    func preparePreviewOfFile(at url: URL, completionHandler handler: @escaping (Error?) -> Void) {
        let result: Result<(NSImage, String), Error>
        do {
            let data = try Data(contentsOf: url)
            let decoded = try decodeJXRWithHDRFallback(data: data)
            guard let nsImage = makeNSImage(from: decoded) else {
                throw JXRDecodeError.decodeFailed(-99)
            }
            let fileSize = ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file)
            let format = decoded.isHDR ? "HDR float" : "SDR"
            let meta = "\(decoded.width)×\(decoded.height) · \(format) · \(fileSize)"
            result = .success((nsImage, meta))
        } catch {
            result = .failure(error)
        }

        DispatchQueue.main.async {
            let previewView: JXRPreviewView
            switch result {
            case .success(let (image, meta)):
                previewView = JXRPreviewView(image: image, metadata: meta)
            case .failure(let error):
                let msg: String
                if let jxrErr = error as? JXRDecodeError {
                    msg = jxrErr.description
                } else {
                    msg = error.localizedDescription
                }
                previewView = JXRPreviewView(error: msg)
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
