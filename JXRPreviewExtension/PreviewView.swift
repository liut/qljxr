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
