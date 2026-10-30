import AppKit
import SwiftUI

// the settings window: a toolbar tab bar (icon over label, like other Mac settings windows)
// with one SwiftUI view per tab. the window title follows the selected tab and the window
// resizes to each tab's height. because the app is an accessory (no dock icon), show()
// activates the app so the window can take focus.
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

// keeps the window title in step with the selected tab.
private final class SettingsTabController: NSTabViewController {
    func addTab<Content: View>(_ label: String, symbol: String, view: Content) {
        let hosting = NSHostingController(rootView: view)
        // size the window to the tab's own content, so short tabs do not leave empty space.
        hosting.sizingOptions = [.preferredContentSize]
        let item = NSTabViewItem(viewController: hosting)
        item.label = label
        item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: label)
        addTabViewItem(item)
    }

    override func tabView(_ tabView: NSTabView, didSelect tabViewItem: NSTabViewItem?) {
        super.tabView(tabView, didSelect: tabViewItem)
        view.window?.title = tabViewItem?.label ?? "Driftwall"
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        view.window?.title = tabView.selectedTabViewItem?.label ?? "Driftwall"
    }
}
