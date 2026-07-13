import AppKit
import DriftwallCore

// wires the infrastructure adapters to the core controller, restores the saved license,
// presents the preferences window, and keeps the environment signals in sync with power and
// occlusion changes.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let power = PowerMonitor()
    private let wallpaper = DesktopVideoWallpaper()
    private let store = FileConfigStore()
    private let systemWallpaper = SystemWallpaperController()
    private let menu = StatusMenuController()
    private var controller: WallpaperController?
    private var preferences: PreferencesWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // agent app: live in the menu bar, no dock icon or main window.
        NSApp.setActivationPolicy(.accessory)

        // if a previous run crashed or was force-killed while it had taken over the desktop
        // picture, put the user's wallpaper back before we do anything else.
        systemWallpaper.recoverIfNeeded()

        let controller = WallpaperController(
            store: store, renderer: wallpaper, systemWallpaper: systemWallpaper)
        self.controller = controller

        // restore the license tier from any stored, still-valid token.
        if let token = controller.config.licenseToken,
           let claims = LicenseVerifier.verify(token: token) {
            controller.setTier(claims.tier)
        }

        let model = PreferencesModel(controller: controller)
        let preferences = PreferencesWindowController(model: model)
        self.preferences = preferences

        menu.onChooseVideo = { [weak self] url in
            self?.controller?.selectVideo(url)
        }
        menu.onOpenPreferences = { [weak preferences] in
            preferences?.show()
        }

        wallpaper.onLoadFailure = { message in
            let alert = NSAlert()
            alert.messageText = "Could not play that video"
            alert.informativeText = message
            alert.alertStyle = .warning
            alert.runModal()
        }
        power.onChange = { [weak self] in self?.syncEnvironment() }
        wallpaper.onOcclusionChange = { [weak self] in self?.syncEnvironment() }
        wallpaper.onScreensChange = { [weak self] in self?.controller?.handleScreensChanged() }
        power.start()

        controller.start(environment: currentEnvironment())

        // no video yet: open preferences so the user can pick one.
        if !controller.config.hasVideo {
            preferences.show()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        // put the user's desktop picture back before we exit.
        controller?.restoreSystemWallpaper()
        power.stop()
    }

    private func currentEnvironment() -> EnvironmentSignals {
        // occlusion already covers a frontmost fullscreen app (it fully covers the wallpaper
        // window), so the dedicated fullscreen signal stays false for now.
        EnvironmentSignals(
            isOccluded: wallpaper.isOccluded,
            isFullscreenAppFrontmost: false,
            isOnBattery: power.isOnBattery
        )
    }

    private func syncEnvironment() {
        controller?.updateEnvironment(currentEnvironment())
    }
}
