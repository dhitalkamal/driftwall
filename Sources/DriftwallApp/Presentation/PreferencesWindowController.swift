import AppKit
import SwiftUI

// the settings window: a toolbar tab bar (icon over label, like other Mac settings windows)
// with one SwiftUI view per tab. the window title follows the selected tab, and every tab is
// the same fixed size so the window never resizes. because the app is an accessory (no dock
// icon), show() activates the app so the window can take focus.
@MainActor
final class PreferencesWindowController: NSWindowController {
    convenience init(model: PreferencesModel) {
        let tabs = SettingsTabController()
        tabs.tabStyle = .toolbar
        tabs.addTab("Wallpaper", symbol: "display", view: WallpaperTab(model: model))
        tabs.addTab("Playlist", symbol: "list.and.film", view: PlaylistTab(model: model))
        tabs.addTab("Behavior", symbol: "gearshape", view: BehaviorTab(model: model))
        tabs.addTab("About", symbol: "info.circle", view: AboutTab(model: model))

        let window = NSWindow(contentViewController: tabs)
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.toolbarStyle = .preference
        window.isReleasedWhenClosed = false
        self.init(window: window)
    }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
    }
}

// builds the toolbar tabs. the window title is bound to this controller's title, which a
// toolbar-style tab controller copies from the selected child controller, so each child's title
// must be its tab label or the window shows "Untitled".
private final class SettingsTabController: NSTabViewController {
    func addTab<Content: View>(_ label: String, symbol: String, view: Content) {
        let hosting = NSHostingController(rootView: view)
        hosting.title = label
        // every tab reports the same fixed page size (SettingsMetrics), so the window keeps
        // one size across tabs.
        hosting.sizingOptions = [.preferredContentSize]
        let item = NSTabViewItem(viewController: hosting)
        item.label = label
        item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: label)
        addTabViewItem(item)
    }
}
