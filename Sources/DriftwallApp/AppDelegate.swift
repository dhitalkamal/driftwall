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
    private var heartbeat: Timer?
    private var rotationTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // agent app: live in the menu bar, no dock icon or main window.
        NSApp.setActivationPolicy(.accessory)
        Diagnostics.log("launch")
        // install a main menu so Cmd+V and other editing shortcuts work in text fields.
        MainMenu.install()

        // if a previous run crashed or was force-killed while it had taken over the desktop
        // picture, put the user's wallpaper back before we do anything else.
        systemWallpaper.recoverIfNeeded()

        let controller = WallpaperController(
            store: store, renderer: wallpaper, systemWallpaper: systemWallpaper)
        self.controller = controller
        controller.onRotationScheduleChanged = { [weak self] in self?.rescheduleRotation() }

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
        wallpaper.onOcclusionChange = { [weak self] in
            Diagnostics.log("occlusionChange: \(self?.wallpaper.diagnostic ?? "-")")
            self?.syncEnvironment()
        }
        wallpaper.onScreensChange = { [weak self] in self?.controller?.handleScreensChanged() }
        wallpaper.onSpaceChange = { [weak self] in
            guard let self else { return }
            Diagnostics.log("spaceChange BEFORE: \(self.wallpaper.diagnostic)")
            self.controller?.handleSpaceChanged()
            Diagnostics.log("spaceChange AFTER: \(self.wallpaper.diagnostic)")
        }
        power.start()

        controller.start(environment: currentEnvironment())
        startHeartbeat()

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

    // (re)schedule the playlist rotation timer to match the controller's current interval.
    private func rescheduleRotation() {
        rotationTimer?.invalidate()
        rotationTimer = nil
        guard let seconds = controller?.rotationIntervalSeconds, seconds > 0 else { return }
        let timer = Timer(timeInterval: TimeInterval(seconds), repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.controller?.advancePlaylist() }
        }
        RunLoop.main.add(timer, forMode: .common)
        rotationTimer = timer
    }

    // periodic state snapshot so the diagnostics log always has a recent picture at the moment
    // a black is observed.
    private func startHeartbeat() {
        let timer = Timer(timeInterval: 3, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                Diagnostics.log("heartbeat: \(self.wallpaper.diagnostic)")
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        heartbeat = timer
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
