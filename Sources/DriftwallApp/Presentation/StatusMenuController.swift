import AppKit
import UniformTypeIdentifiers

// the menu-bar status item and its menu. owns no app logic; it surfaces user intent through
// callbacks the app delegate wires up, and reflects current state via syncState.
@MainActor
final class StatusMenuController: NSObject {
    var onChooseVideo: ((URL) -> Void)?
    var onTogglePauseOnBattery: ((Bool) -> Void)?
    var onToggleLaunchAtLogin: ((Bool) -> Void)?

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let pauseOnBatteryItem = NSMenuItem(
        title: "Pause on Battery", action: nil, keyEquivalent: ""
    )
    private let launchAtLoginItem = NSMenuItem(
        title: "Launch at Login", action: nil, keyEquivalent: ""
    )

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

        menu.addItem(.separator())

        pauseOnBatteryItem.action = #selector(togglePauseOnBattery)
        pauseOnBatteryItem.target = self
        menu.addItem(pauseOnBatteryItem)

        launchAtLoginItem.action = #selector(toggleLaunchAtLogin)
        launchAtLoginItem.target = self
        menu.addItem(launchAtLoginItem)

        menu.addItem(.separator())

        let quit = NSMenuItem(
            title: "Quit Driftwall", action: #selector(quit), keyEquivalent: "q"
        )
        quit.target = self
        menu.addItem(quit)

        statusItem.menu = menu
    }

    // reflect current settings in the menu checkmarks.
    func syncState(pauseOnBattery: Bool, launchAtLogin: Bool) {
        pauseOnBatteryItem.state = pauseOnBattery ? .on : .off
        launchAtLoginItem.state = launchAtLogin ? .on : .off
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

    @objc private func togglePauseOnBattery() {
        let newValue = pauseOnBatteryItem.state != .on
        pauseOnBatteryItem.state = newValue ? .on : .off
        onTogglePauseOnBattery?(newValue)
    }

    @objc private func toggleLaunchAtLogin() {
        let newValue = launchAtLoginItem.state != .on
        launchAtLoginItem.state = newValue ? .on : .off
        onToggleLaunchAtLogin?(newValue)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
