import SwiftUI
import UniformTypeIdentifiers
import DriftwallCore

// a rounded video-still preview that mirrors the chosen fit mode and accepts a dropped video.
struct VideoPreview: View {
    let image: NSImage?
    let name: String
    let fitMode: FitMode
    let onDropVideo: (URL) -> Void
    @State private var targeted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack {
                if let image {
                    Rectangle().fill(.black)  // letterbox backdrop, so Fit shows real bars
                    fitted(image)
                } else {
                    Rectangle().fill(.quaternary)
                    VStack(spacing: 6) {
                        Image(systemName: "photo").font(.system(size: 26)).foregroundStyle(.secondary)
                        Text("Drag a video here, or choose one below")
                            .font(.callout).foregroundStyle(.secondary)
                    }
                }
            }
            .frame(height: 150)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(targeted ? Color.accentColor : Color.gray.opacity(0.3),
                                  lineWidth: targeted ? 2 : 1)
            )
            .onDrop(of: [UTType.fileURL], isTargeted: $targeted) { providers in
                handleDrop(providers)
            }

            if image != nil {
                Label(name, systemImage: "film")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
    }

    // render the still with the same gravity the wallpaper uses, so the preview reflects the
    // effect of the fit mode: Fit letterboxes, Fill crops, Stretch distorts.
    @ViewBuilder
    private func fitted(_ image: NSImage) -> some View {
        switch fitMode {
        case .fill:
            Image(nsImage: image).resizable().aspectRatio(contentMode: .fill)
        case .fit:
            Image(nsImage: image).resizable().aspectRatio(contentMode: .fit)
        case .stretch:
            Image(nsImage: image).resizable()
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { item, _ in
            guard let data = item as? Data,
                  let url = URL(dataRepresentation: data, relativeTo: nil),
                  ["mp4", "m4v", "mov"].contains(url.pathExtension.lowercased())
            else { return }
            DispatchQueue.main.async { onDropVideo(url) }
        }
        return true
    }
}
