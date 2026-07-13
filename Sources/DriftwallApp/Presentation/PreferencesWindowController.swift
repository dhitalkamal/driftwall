import AppKit
import SwiftUI

// hosts the SwiftUI preferences view in a standard window. because the app is an accessory
// (no dock icon), show() activates the app so the window can take focus.
@MainActor
final class PreferencesWindowController: NSWindowController {
    convenience init(model: PreferencesModel) {
        let hosting = NSHostingController(rootView: PreferencesView(model: model))
        let window = NSWindow(contentViewController: hosting)
        window.title = "Driftwall"
        window.styleMask = [.titled, .closable, .miniaturizable]
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
