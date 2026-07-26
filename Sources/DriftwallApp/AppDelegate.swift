import AppKit
import DriftwallCore

// wires the infrastructure adapters to the core controller, presents the preferences window,
// and keeps the environment signals in sync with power and occlusion changes.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let power = PowerMonitor()
    private let wallpaper = DesktopVideoWallpaper()
    private let store = FileConfigStore()
    private let systemWallpaper = SystemWallpaperController()
    private let menu = StatusMenuController()
    private var controller: WallpaperController?
    private var preferences: PreferencesWindowController?
    private var rotationTimer: Timer?
    private var activity: NSObjectProtocol?
    private var occlusionDebounce: Timer?
    // debounced "the wallpaper is genuinely not visible": true only after sustained occlusion,
    // so a brief occlusion during a Space switch never pauses (which would strand a frame).
    private var effectivelyHidden = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        // agent app: live in the menu bar, no dock icon or main window.
        NSApp.setActivationPolicy(.accessory)
        Diagnostics.log("launch")
        // keep decoding/compositing the wallpaper even when it is off the active Space or
        // occluded; otherwise App Nap throttles rendering and the video is stale for a beat on
        // Space return. allows normal idle system sleep, so it does not keep the Mac awake.
        activity = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiatedAllowingIdleSystemSleep],
            reason: "Continuously rendering the live wallpaper across Spaces"
        )
        // install a main menu so Cmd+V and other editing shortcuts work in text fields.
        MainMenu.install()

        // if a previous run crashed or was force-killed while it had taken over the desktop
        // picture, put the user's wallpaper back before we do anything else.
        systemWallpaper.recoverIfNeeded()

        let controller = WallpaperController(
            store: store, renderer: wallpaper, systemWallpaper: systemWallpaper)
        self.controller = controller
        controller.onRotationScheduleChanged = { [weak self] in self?.rescheduleRotation() }

        let model = PreferencesModel(controller: controller)
        let preferences = PreferencesWindowController(model: model)
        self.preferences = preferences

        menu.onChooseVideo = { [weak self] url in
            self?.controller?.selectVideo(url)
        }
        menu.onOpenPreferences = { [weak preferences] in
            preferences?.show()
        }
        controller.onPlaybackStateChanged = { [weak self] state in
            self?.menu.setPlaying(state == .playing)
        }

        wallpaper.onLoadFailure = { message in
            let alert = NSAlert()
            alert.messageText = "Could not play that video"
            alert.informativeText = message
            alert.alertStyle = .warning
            alert.runModal()
        }
        power.onChange = { [weak self] in self?.syncEnvironment() }
        wallpaper.onOcclusionChange = { [weak self] in self?.handleOcclusionChange() }
        wallpaper.onScreensChange = { [weak self] in self?.controller?.handleScreensChanged() }
        wallpaper.onSpaceChange = { [weak self] in
            guard let self else { return }
            // a Space change means visibility is about to flip; assume visible and cancel any
            // pending hide so we never resume into a paused (black) frame. occlusion re-evaluates
            // from scratch afterward and can re-pause if the new Space still hides the wallpaper.
            self.occlusionDebounce?.invalidate()
            self.occlusionDebounce = nil
            self.effectivelyHidden = false
            self.controller?.handleSpaceChanged()
        }
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

    // occlusion changes constantly during Space switches, so debounce before treating the
    // wallpaper as hidden: pause 4K decode only after it has been continuously covered for a
    // while (saves power under a fullscreen app or maximized window), and resume instantly the
    // moment it becomes visible again. brief switch-time occlusion never trips the pause.
    private func handleOcclusionChange() {
        occlusionDebounce?.invalidate()
        occlusionDebounce = nil
        if wallpaper.isOccluded {
            let timer = Timer(timeInterval: 8, repeats: false) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self, self.wallpaper.isOccluded else { return }
                    self.effectivelyHidden = true
                    self.syncEnvironment()
                }
            }
            RunLoop.main.add(timer, forMode: .common)
            occlusionDebounce = timer
        } else if effectivelyHidden {
            effectivelyHidden = false
            syncEnvironment()
        }
    }

    private func currentEnvironment() -> EnvironmentSignals {
        EnvironmentSignals(
            isOccluded: effectivelyHidden,
            isFullscreenAppFrontmost: false,
            isOnBattery: power.isOnBattery
        )
    }

    private func syncEnvironment() {
        controller?.updateEnvironment(currentEnvironment())
    }
}
