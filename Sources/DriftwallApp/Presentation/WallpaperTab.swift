import SwiftUI
import DriftwallCore

// the first tab: the screen-shaped preview, the chosen file with its details, and the
// picture and sound controls grouped under it.
struct WallpaperTab: View {
    @ObservedObject var model: PreferencesModel

    var body: some View {
        SettingsPage {
            ScreenPreview(
                image: model.previewImage,
                fitMode: model.fitMode,
                dim: model.dim,
                onDropVideo: { model.setVideo($0) }
            )
            fileLine
            SettingsGroup(header: "Picture and sound") {
                SettingsRow(title: "Fit", isFirst: true) {
                    Picker("Fit", selection: Binding(get: { model.fitMode }, set: { model.updateFitMode($0) })) {
                        Text("Fill").tag(FitMode.fill)
                        Text("Fit").tag(FitMode.fit)
                        Text("Stretch").tag(FitMode.stretch)
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .fixedSize()
                }
                SliderRow(symbol: "sun.min", title: "Dim", value: playback(\.dim), range: 0...1,
                          valueText: "\(Int(model.dim * 100))%")
                SliderRow(symbol: "gauge.with.dots.needle.33percent", title: "Speed", value: playback(\.speed),
                          range: 0.25...2, step: 0.25, valueText: speedText)
                SliderRow(symbol: model.volume > 0 ? "speaker.wave.2" : "speaker.slash", title: "Volume",
                          value: playback(\.volume), range: 0...1,
                          valueText: model.volume > 0 ? "\(Int(model.volume * 100))%" : "Off")
            }
        }
    }

    private var fileLine: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 1) {
                Text(hasVideo ? model.selectedVideoName : "No video chosen")
                    .font(.body.weight(.semibold))
                    .lineLimit(1).truncationMode(.middle)
                Text(hasVideo ? model.videoDetails : "Your usual desktop picture is showing")
                    .font(.caption).foregroundStyle(.secondary).monospacedDigit()
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Button("Choose Video...") { model.chooseVideo() }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut("o")
            Button("Remove") { model.removeWallpaper() }
                .disabled(!hasVideo)
        }
    }

    private var hasVideo: Bool { model.selectedVideoName != "None" }

    // "1x", "0.25x", "1.5x": drop trailing zeros so the common case reads cleanly.
    private var speedText: String {
        var text = String(format: "%.2f", model.speed)
        while text.hasSuffix("0") { text.removeLast() }
        if text.hasSuffix(".") { text.removeLast() }
        return text + "x"
    }

    // write a playback slider straight through to the controller, like the old Playback tab did.
    private func playback(_ keyPath: ReferenceWritableKeyPath<PreferencesModel, Double>) -> Binding<Double> {
        Binding(
            get: { model[keyPath: keyPath] },
            set: { model[keyPath: keyPath] = $0; model.updatePlayback() }
        )
    }
}
