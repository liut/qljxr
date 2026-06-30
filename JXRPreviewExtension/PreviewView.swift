import SwiftUI

struct JXRPreviewView: View {
    let nsImage: NSImage?
    let errorMessage: String?
    let metadata: String?

    init(image: NSImage, metadata: String? = nil) {
        self.nsImage = image
        self.errorMessage = nil
        self.metadata = metadata
    }

    init(error: String) {
        self.nsImage = nil
        self.errorMessage = error
        self.metadata = nil
    }

    var body: some View {
        if let image = nsImage {
            VStack(spacing: 0) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)

                if let meta = metadata {
                    HStack {
                        Text(meta)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(.regularMaterial)
                }
            }
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
