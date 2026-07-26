import SwiftUI
import DriftwallCore

// the preferences window, organized as tabs so every control is always reachable without
// scrolling past the fold.
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
        .frame(minWidth: 460, minHeight: 420)
        .padding(.top, 4)
    }
}

private struct GeneralTab: View {
    @ObservedObject var model: PreferencesModel

    var body: some View {
        Form {
            Section("Wallpaper") {
                LabeledContent("Video", value: model.selectedVideoName)
                HStack {
                    Button("Choose Video...") { model.chooseVideo() }
                    Button("Remove") { model.removeWallpaper() }
                        .disabled(model.selectedVideoName == "None")
                }
                Picker("Fit", selection: Binding(
                    get: { model.fitMode }, set: { model.updateFitMode($0) }
                )) {
                    Text("Fill").tag(FitMode.fill)
                    Text("Fit").tag(FitMode.fit)
                    Text("Stretch").tag(FitMode.stretch)
                }
                .pickerStyle(.segmented)
            }
            Section("Behavior") {
                Toggle("Show on all Spaces", isOn: Binding(
                    get: { model.showOnAllSpaces }, set: { model.updateShowOnAllSpaces($0) }))
                Toggle("Pause on battery", isOn: Binding(
                    get: { model.pauseOnBattery }, set: { model.updatePauseOnBattery($0) }))
                Toggle("Replace system wallpaper while active", isOn: Binding(
                    get: { model.replaceSystemWallpaper }, set: { model.updateReplaceSystemWallpaper($0) }))
                Toggle("Launch at login", isOn: Binding(
                    get: { model.launchAtLogin }, set: { model.updateLaunchAtLogin($0) }))
            }
        }
        .formStyle(.grouped)
    }
}

private struct PlaybackTab: View {
    @ObservedObject var model: PreferencesModel

    var body: some View {
        Form {
            Section("Playback") {
                Slider(value: bind(\.volume), in: 0...1) { Text("Volume") }
                Slider(value: bind(\.dim), in: 0...1) { Text("Dim") }
            }
            Section("Speed") {
                Slider(value: bind(\.speed), in: 0.25...2.0, step: 0.25) {
                    Text("Speed")
                } minimumValueLabel: { Text("0.25x") } maximumValueLabel: { Text("2x") }
                Text(String(format: "%.2fx", model.speed))
                    .font(.callout).foregroundStyle(.secondary)
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
            Section("Playlist") {
                Toggle("Rotate through a playlist", isOn: Binding(
                    get: { model.playlistEnabled }, set: { model.updatePlaylistEnabled($0) }))
                Toggle("Shuffle", isOn: Binding(
                    get: { model.playlistShuffle }, set: { model.updatePlaylistShuffle($0) }))
                Stepper("Rotate every \(model.playlistIntervalMinutes) min", value: Binding(
                    get: { model.playlistIntervalMinutes },
                    set: { model.updatePlaylistInterval($0) }), in: 1...240)
            }
            Section("Videos (\(model.playlistVideoNames.count))") {
                ForEach(Array(model.playlistVideoNames.enumerated()), id: \.offset) { index, name in
                    HStack {
                        Text(name).lineLimit(1).truncationMode(.middle)
                        Spacer()
                        Button("Remove") { model.removePlaylistVideo(at: index) }
                    }
                }
                HStack {
                    Button("Add Videos...") { model.addPlaylistVideos() }
                    Button("Add Folder...") { model.addPlaylistFolder() }
                }
            }
        }
        .formStyle(.grouped)
    }
}

private struct AboutTab: View {
    @ObservedObject var model: PreferencesModel

    var body: some View {
        Form {
            Section {
                LabeledContent("Driftwall", value: model.appVersion)
                Text("Live video wallpaper for macOS.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}
