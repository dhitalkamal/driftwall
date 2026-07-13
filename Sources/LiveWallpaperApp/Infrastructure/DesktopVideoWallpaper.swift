import AppKit
import LiveWallpaperCore

// implements the WallpaperRendering port with AppKit: one borderless desktop-level window per
// screen, all bound to a single looping player. rebuilds windows when the display arrangement
// changes and reports occlusion changes so the controller can pause hidden playback.
@MainActor
final class DesktopVideoWallpaper: WallpaperRendering {
    private let looper = VideoLooperPlayer()
    private var windows: [WallpaperWindow] = []
    private var currentURL: URL?
    private var rebuildWork: DispatchWorkItem?
    private var observers: [NSObjectProtocol] = []

    // invoked (on the main thread) whenever a window's occlusion state changes.
    var onOcclusionChange: (@MainActor () -> Void)?

    init() {
        let center = NotificationCenter.default
        observers.append(center.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { _ in
            MainActor.assumeIsolated { self.scheduleRebuild() }
        })
        observers.append(center.addObserver(
            forName: NSWindow.didChangeOcclusionStateNotification,
            object: nil,
            queue: .main
        ) { _ in
            MainActor.assumeIsolated { self.onOcclusionChange?() }
        })
    }

    // true when a video is loaded but no window is currently visible (fully covered, or a
    // fullscreen app is frontmost). used to pause playback that no one can see.
    var isOccluded: Bool {
        guard !windows.isEmpty else { return false }
        return windows.allSatisfy { !$0.occlusionState.contains(.visible) }
    }

    func show(video url: URL) {
        currentURL = url
        looper.load(url: url)
        rebuildWindows()
    }

    func play() {
        looper.play()
    }

    func pause() {
        looper.pause()
    }

    func hide() {
        rebuildWork?.cancel()
        for window in windows {
            window.orderOut(nil)
        }
        windows.removeAll()
        looper.teardown()
        currentURL = nil
    }

    // coalesce bursts of screen-parameter notifications into a single rebuild.
    private func scheduleRebuild() {
        rebuildWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated { self?.rebuildWindows() }
        }
        rebuildWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: work)
    }

    private func rebuildWindows() {
        guard currentURL != nil else { return }
        for window in windows {
            window.orderOut(nil)
        }
        windows = NSScreen.screens.map { screen in
            let window = WallpaperWindow(screen: screen)
            window.playerView.bind(to: looper.player)
            window.orderFront(nil)
            return window
        }
    }
}
