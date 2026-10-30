import SwiftUI

// rotation settings, then the playlist as a filmstrip: thumbnail, name, and either "Now
// playing" or the loop length on each row.
struct PlaylistTab: View {
    @ObservedObject var model: PreferencesModel

    var body: some View {
        SettingsPage {
            SettingsGroup(header: "Rotation") {
                ToggleRow(title: "Rotate through a playlist", hint: "Needs two or more videos", isFirst: true,
                          isOn: Binding(get: { model.playlistEnabled }, set: { model.updatePlaylistEnabled($0) }))
                ToggleRow(title: "Shuffle",
                          isOn: Binding(get: { model.playlistShuffle }, set: { model.updatePlaylistShuffle($0) }))
                SettingsRow(title: "Change video every") {
                    Stepper(value: Binding(get: { model.playlistIntervalMinutes },
                                           set: { model.updatePlaylistInterval($0) }), in: 1...240) {
                        Text("\(model.playlistIntervalMinutes) min").monospacedDigit()
                    }
                }
            }
            SettingsGroup(header: "Videos (\(model.playlistVideos.count))") {
                if model.playlistVideos.isEmpty {
                    SettingsRow(title: "No videos yet", hint: "Add files, or a whole folder at once.", isFirst: true) {
                        EmptyView()
                    }
                }
                ForEach(Array(model.playlistVideos.enumerated()), id: \.offset) { index, url in
                    row(index: index, url: url)
                }
            }
            HStack(spacing: 8) {
                Button("Add Videos...") { model.addPlaylistVideos() }
                Button("Add Folder...") { model.addPlaylistFolder() }
            }
        }
    }

    private func row(index: Int, url: URL) -> some View {
        let isPlaying = model.playlistEnabled && model.currentVideoURL == url
        return VStack(spacing: 0) {
            // inset past the thumbnail so the line starts under the file name.
            if index > 0 { RowDivider(leadingInset: SettingsMetrics.rowInset + 64 + 12) }
            HStack(spacing: 12) {
                thumbnail(for: url)
                VStack(alignment: .leading, spacing: 1) {
                    Text(url.lastPathComponent).lineLimit(1).truncationMode(.middle)
                    if isPlaying {
                        Text("Now playing").font(.caption.weight(.semibold)).foregroundStyle(.tint)
                    } else if let length = model.playlistLengths[url] {
                        Text("\(length) loop").font(.caption).foregroundStyle(.secondary).monospacedDigit()
                    }
                }
                Spacer(minLength: 8)
                Button {
                    model.removePlaylistVideo(at: index)
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Remove from playlist")
                .accessibilityLabel("Remove \(url.lastPathComponent) from playlist")
            }
            .padding(.horizontal, SettingsMetrics.rowInset)
            .padding(.vertical, SettingsMetrics.rowVertical)
        }
    }

    private func thumbnail(for url: URL) -> some View {
        ZStack {
            Color.black.opacity(0.12)
            if let still = model.playlistStills[url] {
                Image(nsImage: still).resizable().aspectRatio(contentMode: .fill)
            } else {
                Image(systemName: "film").foregroundStyle(.secondary)
            }
        }
        .frame(width: 64, height: 40)
        .clipShape(RoundedRectangle(cornerRadius: 5))
        .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(.separator, lineWidth: 0.5))
        .accessibilityHidden(true)
    }
}
