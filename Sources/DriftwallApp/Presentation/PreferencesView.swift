import SwiftUI
import DriftwallCore

// the preferences window, organized as tabs so every control (including license activation)
// is always reachable without scrolling past the fold.
struct PreferencesView: View {
    @ObservedObject var model: PreferencesModel

    var body: some View {
        TabView {
            GeneralTab(model: model)
                .tabItem { Label("General", systemImage: "gearshape") }
            PlaybackTab(model: model)
                .tabItem { Label("Playback", systemImage: "slider.horizontal.3") }
            ProTab(model: model)
                .tabItem { Label("Pro", systemImage: "star") }
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

private struct ProTab: View {
    @ObservedObject var model: PreferencesModel

    var body: some View {
        Form {
            Section("Driftwall Pro") {
                LabeledContent("Status", value: model.isPro ? "Pro" : "Free")
                Text("Pro unlocks a different video per display, playlists with scheduled rotation, and (soon) Lock Screen video.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Section(model.isPro ? "License" : "Activate") {
                if model.isPro {
                    Button("Deactivate license") { model.deactivateLicense() }
                } else {
                    TextField("Paste your license key", text: $model.licenseKeyInput, axis: .vertical)
                        .lineLimit(2...4)
                        .textFieldStyle(.roundedBorder)
                    HStack {
                        Button("Paste from Clipboard") { model.pasteLicenseFromClipboard() }
                        Spacer()
                        Button("Activate") { model.activateLicense() }
                            .keyboardShortcut(.defaultAction)
                            .disabled(model.licenseKeyInput.isEmpty)
                    }
                }
                if !model.licenseMessage.isEmpty {
                    Text(model.licenseMessage).font(.callout).foregroundStyle(.secondary)
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
