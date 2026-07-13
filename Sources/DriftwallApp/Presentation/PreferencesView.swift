import SwiftUI
import DriftwallCore

// the preferences window content. a scrolling form of sections; pro-only features are shown
// with their lock state so the value of upgrading is visible.
struct PreferencesView: View {
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
                Picker("Fit", selection: fitBinding) {
                    Text("Fill").tag(FitMode.fill)
                    Text("Fit").tag(FitMode.fit)
                    Text("Stretch").tag(FitMode.stretch)
                }
                .pickerStyle(.segmented)
            }

            Section("Playback") {
                Slider(value: playbackBinding(\.volume), in: 0...1) { Text("Volume") }
                Slider(value: playbackBinding(\.dim), in: 0...1) { Text("Dim") }
            }

            Section("Power") {
                Toggle("Pause on battery", isOn: pauseOnBatteryBinding)
                Toggle("Launch at login", isOn: launchAtLoginBinding)
            }

            Section("Driftwall Pro") {
                LabeledContent("Status", value: model.isPro ? "Pro" : "Free")
                if !model.isPro {
                    Text("Pro unlocks a different video per display, playlists with scheduled rotation, and (soon) Lock Screen video.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    HStack {
                        TextField("License key", text: $model.licenseKeyInput)
                        Button("Activate") { model.activateLicense() }
                    }
                }
                if !model.licenseMessage.isEmpty {
                    Text(model.licenseMessage).font(.callout).foregroundStyle(.secondary)
                }
            }

            Section("About") {
                LabeledContent("Driftwall", value: model.appVersion)
                Text("Live video wallpaper for macOS.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 520)
    }

    private var fitBinding: Binding<FitMode> {
        Binding(get: { model.fitMode }, set: { model.updateFitMode($0) })
    }

    private var pauseOnBatteryBinding: Binding<Bool> {
        Binding(get: { model.pauseOnBattery }, set: { model.updatePauseOnBattery($0) })
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(get: { model.launchAtLogin }, set: { model.updateLaunchAtLogin($0) })
    }

    private func playbackBinding(_ keyPath: ReferenceWritableKeyPath<PreferencesModel, Double>) -> Binding<Double> {
        Binding(
            get: { model[keyPath: keyPath] },
            set: { model[keyPath: keyPath] = $0; model.updatePlayback() }
        )
    }
}
