import SwiftUI

// when the wallpaper pauses, and how it sits on the desktop.
struct BehaviorTab: View {
    @ObservedObject var model: PreferencesModel

    var body: some View {
        SettingsPage {
            SettingsGroup(header: "When to pause") {
                ToggleRow(title: "Pause on battery", hint: "Resumes when you plug in", isFirst: true,
                          isOn: Binding(get: { model.pauseOnBattery }, set: { model.updatePauseOnBattery($0) }))
                RowDivider()
                VStack(alignment: .leading, spacing: 10) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Fullscreen app on one display")
                        Text("With a single display, Driftwall always pauses while a fullscreen app is in front.")
                            .font(.caption).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    FullscreenChoiceCards(selection: model.fullscreenBehavior) {
                        model.updateFullscreenBehavior($0)
                    }
                }
                .padding(.horizontal, SettingsMetrics.rowInset)
                .padding(.top, SettingsMetrics.rowVertical)
                .padding(.bottom, SettingsMetrics.rowInset)
            }
            SettingsGroup(header: "Desktop") {
                ToggleRow(title: "Show on all Spaces", isFirst: true,
                          isOn: Binding(get: { model.showOnAllSpaces }, set: { model.updateShowOnAllSpaces($0) }))
                ToggleRow(title: "Replace desktop picture while running", hint: "Your picture comes back when you quit",
                          isOn: Binding(get: { model.replaceSystemWallpaper },
                                        set: { model.updateReplaceSystemWallpaper($0) }))
                ToggleRow(title: "Open at login",
                          isOn: Binding(get: { model.launchAtLogin }, set: { model.updateLaunchAtLogin($0) }))
            }
        }
    }
}
