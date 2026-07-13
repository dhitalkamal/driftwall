import AppKit
import UniformTypeIdentifiers

// the menu-bar status item and its menu. owns no app logic; it surfaces user intent through
// callbacks the app delegate wires up. detailed settings live in the preferences window.
@MainActor
final class StatusMenuController: NSObject {
    var onChooseVideo: ((URL) -> Void)?
    var onOpenPreferences: (() -> Void)?

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

    override init() {
        super.init()
        configure()
    }

    private func configure() {
        if let button = statusItem.button {
            button.image = NSImage(
                systemSymbolName: "menubar.dock.rectangle",
                accessibilityDescription: "Driftwall"
            )
        }

        let menu = NSMenu()

        let choose = NSMenuItem(
            title: "Choose Video...", action: #selector(chooseVideo), keyEquivalent: "o"
        )
        choose.target = self
        menu.addItem(choose)

        let prefs = NSMenuItem(
            title: "Preferences...", action: #selector(openPreferences), keyEquivalent: ","
        )
        prefs.target = self
        menu.addItem(prefs)

        menu.addItem(.separator())

        let quit = NSMenuItem(
            title: "Quit Driftwall", action: #selector(quit), keyEquivalent: "q"
        )
        quit.target = self
        menu.addItem(quit)

        statusItem.menu = menu
    }

    @objc private func chooseVideo() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.movie, .mpeg4Movie, .quickTimeMovie]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.prompt = "Set Wallpaper"
        if panel.runModal() == .OK, let url = panel.url {
            onChooseVideo?(url)
        }
    }

    @objc private func openPreferences() {
        onOpenPreferences?()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
