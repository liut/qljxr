import SwiftUI
import Combine

@main
struct HostApp: App {
    @StateObject private var model = ViewerModel()

    var body: some Scene {
        WindowGroup {
            ContentView(model: model)
                .frame(minWidth: 400, minHeight: 300)
                .navigationTitle(model.filename)
                .onOpenURL { url in
                    model.load(url: url)
                }
        }
        .commands {
            CommandGroup(after: .newItem) {
                Button("Open JPEG XR...") {
                    model.open()
                }
                .keyboardShortcut("o", modifiers: .command)
            }
        }
    }
}

struct ContentView: View {
    @ObservedObject var model: ViewerModel

    var body: some View {
        VStack(spacing: 0) {
            if let image = model.image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)

                // Metadata bar
                HStack(spacing: 8) {
                    Text("\(model.imageWidth)×\(model.imageHeight)")
                    if !model.colorFormat.isEmpty {
                        Text("·")
                        Text(model.colorFormat)
                    }
                    Text("·")
                    Text(model.fileSizeText)
                    Spacer()
                }
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(.regularMaterial)
            } else if let error = model.errorMessage {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                    Text(error)
                        .foregroundColor(.secondary)
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "photo")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("Open a JPEG XR (.jxr) file")
                        .foregroundColor(.secondary)
                    Button("Open File...") {
                        model.open()
                    }
                    .padding(.top, 8)
                }
            }
        }
    }
}

final class ViewerModel: ObservableObject {
    @Published var image: NSImage?
    @Published var errorMessage: String?
    @Published var filename: String = ""
    @Published var imageWidth = 0
    @Published var imageHeight = 0
    @Published var colorFormat = ""
    @Published var fileSizeText = ""

    func open() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.jxr]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        load(url: url)
    }

    func load(url: URL) {
        filename = url.lastPathComponent

        do {
            let data = try Data(contentsOf: url)
            let decoded = try decodeJXRWithHDRFallback(data: data)
            guard let nsImage = makeNSImage(from: decoded) else {
                image = nil
                errorMessage = "无法创建图像"
                return
            }
            image = nsImage
            imageWidth = decoded.width
            imageHeight = decoded.height
            colorFormat = decoded.isHDR ? "HDR float" : "SDR"
            fileSizeText = ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file)
            errorMessage = nil
            resizeWindow(forImageWidth: decoded.width, height: decoded.height)
        } catch {
            image = nil
            if let jxrErr = error as? JXRDecodeError {
                errorMessage = jxrErr.description
            } else {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func resizeWindow(forImageWidth w: Int, height h: Int) {
        guard let window = NSApp.keyWindow ?? NSApp.windows.first else { return }
        guard let screen = window.screen ?? NSScreen.main else { return }

        // Content size: image at 1x + metadata bar (~24 pt) + padding
        let contentW = CGFloat(w)
        let contentH = CGFloat(h) + 24

        // Constrain to 85% of visible screen area
        let visible = screen.visibleFrame
        let maxW = visible.width * 0.85
        let maxH = visible.height * 0.85

        let scale = min(1.0, min(maxW / contentW, maxH / contentH))
        let scaledW = contentW * scale
        let scaledH = contentH * scale

        let frame = NSRect(
            x: visible.midX - scaledW / 2,
            y: visible.midY - scaledH / 2,
            width: scaledW,
            height: scaledH
        )
        window.setFrame(frame, display: true, animate: true)
    }
}
