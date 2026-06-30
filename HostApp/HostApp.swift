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
        Group {
            if let image = model.image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
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

    func open() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.jxr]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }

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
            errorMessage = nil
        } catch {
            image = nil
            if let jxrErr = error as? JXRDecodeError {
                errorMessage = jxrErr.description
            } else {
                errorMessage = error.localizedDescription
            }
        }
    }
}
