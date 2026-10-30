import SwiftUI

// app identity as a compact header row, then grouped rows for links, help and the license,
// laid out top-down like every other tab.
struct AboutTab: View {
    @ObservedObject var model: PreferencesModel

    private static let repo = "https://github.com/dhitalkamal/driftwall"

    var body: some View {
        SettingsPage {
            header
            SettingsGroup(header: "Links") {
                linkRow("GitHub", hint: "Source code and releases", path: "", isFirst: true)
                linkRow("Report an issue", hint: "Bugs and feature requests", path: "/issues")
                linkRow("Privacy policy", hint: "Nothing leaves your Mac", path: "/blob/main/legal/PRIVACY.md")
            }
            SettingsGroup(header: "Help") {
                SettingsRow(title: "Something not working?",
                            hint: "The diagnostics log records pauses, fullscreen changes and Space switches.",
                            isFirst: true) {
                    Button("Show Log in Finder") { model.showLog() }
                }
            }
            SettingsGroup(header: "License") {
                linkRow("MIT License", hint: "Copyright 2026 Kamal Dhital", path: "/blob/main/LICENSE",
                        isFirst: true, action: "View")
            }
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable().frame(width: 64, height: 64)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("Driftwall").font(.title2.weight(.semibold))
                Text("Version \(model.appVersion)").font(.callout).foregroundStyle(.secondary).monospacedDigit()
                Text("Live video wallpaper for your Mac.").font(.callout)
            }
        }
        .padding(.horizontal, 4)
        .accessibilityElement(children: .combine)
    }

    // a row that opens a page of the repository in the browser.
    private func linkRow(_ title: String, hint: String, path: String, isFirst: Bool = false,
                         action: String = "Open") -> some View {
        SettingsRow(title: title, hint: hint, isFirst: isFirst) {
            Button(action) {
                if let url = URL(string: Self.repo + path) { NSWorkspace.shared.open(url) }
            }
            .accessibilityLabel("\(action) \(title)")
        }
    }
}
