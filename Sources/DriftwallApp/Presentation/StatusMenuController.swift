import AppKit
import UniformTypeIdentifiers

// the menu-bar status item and its menu. owns no app logic; it surfaces user intent through
// callbacks the app delegate wires up, and reads live state through the providers below.
// the dynamic items (current video, pause/resume, next) are rebuilt each time the menu opens.
@MainActor
final class StatusMenuController: NSObject, NSMenuDelegate {
    var onChooseVideo: ((URL) -> Void)?
    var onOpenPreferences: (() -> Void)?
    var onTogglePause: (() -> Void)?
    var onNext: (() -> Void)?

    // live state read when the menu is about to open.
    var currentVideoName: (() -> String?)?
    var isPaused: (() -> Bool)?
    var isPlaylistActive: (() -> Bool)?

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

    override init() {
        super.init()
        statusItem.button?.image = MenuBarIcon.make(active: false)
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
    }

    // reflect playback state in the menu-bar glyph: solid when playing, dimmed otherwise.
    func setPlaying(_ playing: Bool) {
        statusItem.button?.image = MenuBarIcon.make(active: playing)
    }

    // rebuild the menu each time it opens so it reflects the current video and playback state.
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let nameItem = NSMenuItem(
            title: currentVideoName?() ?? "No video", action: nil, keyEquivalent: ""
        )
        nameItem.isEnabled = false
        menu.addItem(nameItem)

        menu.addItem(.separator())

        let paused = isPaused?() ?? false
        let pauseItem = NSMenuItem(
            title: paused ? "Resume" : "Pause", action: #selector(togglePause), keyEquivalent: ""
        )
        pauseItem.target = self
        menu.addItem(pauseItem)

        if isPlaylistActive?() == true {
            let next = NSMenuItem(title: "Next Video", action: #selector(nextVideo), keyEquivalent: "")
            next.target = self
            menu.addItem(next)
        }

        menu.addItem(.separator())

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

        let quit = NSMenuItem(title: "Quit Driftwall", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
    }

    @objc private func togglePause() { onTogglePause?() }

    @objc private func nextVideo() { onNext?() }

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
