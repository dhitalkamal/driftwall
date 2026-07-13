import AppKit
import DriftwallCore

// wires the infrastructure adapters to the core controller and keeps the environment
// signals fed to the controller in sync with power and occlusion changes.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let power = PowerMonitor()
    private let wallpaper = DesktopVideoWallpaper()
    private let store = FileConfigStore()
    private let menu = StatusMenuController()
    private var controller: WallpaperController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // agent app: live in the menu bar, no dock icon or main window.
        NSApp.setActivationPolicy(.accessory)

        let controller = WallpaperController(store: store, renderer: wallpaper)
        self.controller = controller

        menu.onChooseVideo = { [weak self] url in
            self?.controller?.selectVideo(url)
        }
        menu.onTogglePauseOnBattery = { [weak self] enabled in
            self?.controller?.setPauseOnBattery(enabled)
        }
        menu.onToggleLaunchAtLogin = { enabled in
            LaunchAtLoginService.setEnabled(enabled)
        }

        power.onChange = { [weak self] in self?.syncEnvironment() }
        wallpaper.onOcclusionChange = { [weak self] in self?.syncEnvironment() }
        power.start()

        controller.start(environment: currentEnvironment())
        menu.syncState(
            pauseOnBattery: controller.config.pauseOnBattery,
            launchAtLogin: LaunchAtLoginService.isEnabled
        )
    }

    func applicationWillTerminate(_ notification: Notification) {
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
