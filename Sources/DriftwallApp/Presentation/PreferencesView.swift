import SwiftUI
import DriftwallCore

// the preferences window, organized as tabs so every control is always reachable without
// scrolling past the fold. tabs are split into focused subviews below.
struct PreferencesView: View {
    @ObservedObject var model: PreferencesModel

    var body: some View {
        TabView {
            GeneralTab(model: model)
                .tabItem { Label("General", systemImage: "gearshape") }
            PlaybackTab(model: model)
                .tabItem { Label("Playback", systemImage: "slider.horizontal.3") }
            PlaylistTab(model: model)
                .tabItem { Label("Playlist", systemImage: "list.and.film") }
            AboutTab(model: model)
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 500, height: 520)
    }
}

private struct GeneralTab: View {
    @ObservedObject var model: PreferencesModel

    var body: some View {
        Form {
            Section {
                VideoPreview(image: model.previewImage, name: model.selectedVideoName)
                    .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
                HStack {
                    Button("Choose Video...") { model.chooseVideo() }
                        .buttonStyle(.borderedProminent)
                    Button("Remove") { model.removeWallpaper() }
                        .disabled(model.selectedVideoName == "None")
                    Spacer()
                }
                Picker("Fit", selection: Binding(
                    get: { model.fitMode }, set: { model.updateFitMode($0) }
                )) {
                    Text("Fill").tag(FitMode.fill)
                    Text("Fit").tag(FitMode.fit)
                    Text("Stretch").tag(FitMode.stretch)
                }
                .pickerStyle(.segmented)
            } header: {
                Label("Wallpaper", systemImage: "photo.on.rectangle.angled")
            }

            Section {
                Toggle("Show on all Spaces", isOn: bind(\.showOnAllSpaces, model.updateShowOnAllSpaces))
                Toggle("Pause on battery", isOn: bind(\.pauseOnBattery, model.updatePauseOnBattery))
                Toggle("Replace system wallpaper while active",
                       isOn: bind(\.replaceSystemWallpaper, model.updateReplaceSystemWallpaper))
                Toggle("Launch at login", isOn: bind(\.launchAtLogin, model.updateLaunchAtLogin))
            } header: {
                Label("Behavior", systemImage: "gearshape")
            }
        }
        .formStyle(.grouped)
    }

    private func bind(_ keyPath: KeyPath<PreferencesModel, Bool>, _ set: @escaping (Bool) -> Void) -> Binding<Bool> {
        Binding(get: { model[keyPath: keyPath] }, set: set)
    }
}

// a rounded video-still preview with the current file name, or an empty-state placeholder.
private struct VideoPreview: View {
    let image: NSImage?
    let name: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack {
                if let image {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Rectangle().fill(.quaternary)
                    VStack(spacing: 6) {
                        Image(systemName: "photo").font(.system(size: 26)).foregroundStyle(.secondary)
                        Text("No video selected").font(.callout).foregroundStyle(.secondary)
                    }
                }
            }
            .frame(height: 150)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.quaternary))

            Label(name, systemImage: "film")
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }
}

private struct PlaybackTab: View {
    @ObservedObject var model: PreferencesModel

    var body: some View {
        Form {
            Section {
                LabeledContent("Volume") {
                    Slider(value: bind(\.volume), in: 0...1)
                    Text("\(Int(model.volume * 100))%").monospacedDigit().foregroundStyle(.secondary)
                }
                LabeledContent("Dim") {
                    Slider(value: bind(\.dim), in: 0...1)
                    Text("\(Int(model.dim * 100))%").monospacedDigit().foregroundStyle(.secondary)
                }
            } header: {
                Label("Playback", systemImage: "speaker.wave.2")
            }

            Section {
                LabeledContent("Speed") {
                    Slider(value: bind(\.speed), in: 0.25...2.0, step: 0.25)
                    Text(String(format: "%.2fx", model.speed)).monospacedDigit().foregroundStyle(.secondary)
                }
            } header: {
                Label("Speed", systemImage: "gauge.with.dots.needle.67percent")
            }
        }
        .formStyle(.grouped)
    }

    private func bind(_ keyPath: ReferenceWritableKeyPath<PreferencesModel, Double>) -> Binding<Double> {
        Binding(
            get: { model[keyPath: keyPath] },
            set: { model[keyPath: keyPath] = $0; model.updatePlayback() }
        )
    }
}

private struct PlaylistTab: View {
    @ObservedObject var model: PreferencesModel

    var body: some View {
        Form {
            Section {
                Toggle("Rotate through a playlist", isOn: Binding(
                    get: { model.playlistEnabled }, set: { model.updatePlaylistEnabled($0) }))
                Toggle("Shuffle", isOn: Binding(
                    get: { model.playlistShuffle }, set: { model.updatePlaylistShuffle($0) }))
                Stepper("Rotate every \(model.playlistIntervalMinutes) min", value: Binding(
                    get: { model.playlistIntervalMinutes },
                    set: { model.updatePlaylistInterval($0) }), in: 1...240)
            } header: {
                Label("Rotation", systemImage: "arrow.triangle.2.circlepath")
            }

            Section {
                if model.playlistVideoNames.isEmpty {
                    Text("No videos yet — add files or a folder below.")
                        .font(.callout).foregroundStyle(.secondary)
                }
                ForEach(Array(model.playlistVideoNames.enumerated()), id: \.offset) { index, name in
                    HStack {
                        Label(name, systemImage: "film")
                            .lineLimit(1).truncationMode(.middle)
                        Spacer()
                        Button {
                            model.removePlaylistVideo(at: index)
                        } label: {
                            Image(systemName: "minus.circle.fill").foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("Remove")
                    }
                }
                HStack {
                    Button { model.addPlaylistVideos() } label: {
                        Label("Add Videos...", systemImage: "plus")
                    }
                    Button { model.addPlaylistFolder() } label: {
                        Label("Add Folder...", systemImage: "folder.badge.plus")
                    }
                    Spacer()
                }
            } header: {
                Label("Videos (\(model.playlistVideoNames.count))", systemImage: "list.and.film")
            }
        }
        .formStyle(.grouped)
    }
}

private struct AboutTab: View {
    @ObservedObject var model: PreferencesModel

    var body: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(nsImage: NSApp.applicationIconImage)
                .resizable().frame(width: 96, height: 96)
            Text("Driftwall").font(.title).fontWeight(.semibold)
            Text("Version \(model.appVersion)").font(.callout).foregroundStyle(.secondary)
            Text("Live video wallpaper for macOS.").font(.callout).foregroundStyle(.secondary)
            Link("View on GitHub", destination: URL(string: "https://github.com/dhitalkamal/driftwall")!)
            Text("MIT licensed").font(.footnote).foregroundStyle(.tertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
