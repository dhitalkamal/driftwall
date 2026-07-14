import AppKit
import DriftwallCore

// implements the WallpaperRendering port with AppKit: one borderless desktop-level window per
// screen, all bound to a single looping player. rebuilds windows when the display arrangement
// changes and reports occlusion changes so the controller can pause hidden playback.
@MainActor
final class DesktopVideoWallpaper: WallpaperRendering {
    private let looper = VideoLooperPlayer()
    private var windows: [WallpaperWindow] = []
    private var currentURL: URL?
    private var currentFitMode: FitMode = .fill
    private var currentDim: Double = 0
    private var currentShowOnAllSpaces = true
    private var rebuildWork: DispatchWorkItem?
    private var observers: [NSObjectProtocol] = []

    // invoked (on the main thread) whenever a window's occlusion state changes.
    var onOcclusionChange: (@MainActor () -> Void)?
    // invoked (on the main thread) after the display arrangement changes and windows rebuild.
    var onScreensChange: (@MainActor () -> Void)?
    // invoked (on the main thread) when the active Space changes.
    var onSpaceChange: (@MainActor () -> Void)?
    // invoked (on the main thread) when the current video fails to load.
    var onLoadFailure: (@MainActor (String) -> Void)? {
        didSet { looper.onLoadFailure = onLoadFailure }
    }

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
        // active-Space changes are posted on NSWorkspace's own notification center, not the
        // default one. this is the reliable resume signal (window occlusion is not).
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil,
            queue: .main
        ) { _ in
            MainActor.assumeIsolated { self.onSpaceChange?() }
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

    func setFitMode(_ mode: FitMode) {
        currentFitMode = mode
        for window in windows {
            window.playerView.setFitMode(mode)
        }
    }

    func setVolume(_ volume: Double) {
        looper.setVolume(volume)
    }

    func setSpeed(_ rate: Double) {
        looper.setSpeed(rate)
    }

    func setDim(_ dim: Double) {
        currentDim = dim
        for window in windows {
            window.playerView.setDim(dim)
        }
    }

    // a compact snapshot of window + player state for the diagnostics log.
    var diagnostic: String {
        let anyVisible = windows.contains { $0.occlusionState.contains(.visible) }
        return "windows=\(windows.count) anyVisible=\(anyVisible) \(looper.diagnostic)"
    }

    // called on Space return: install fresh AVPlayerLayer surfaces (the old ones stop
    // compositing after being off a non-active Space, leaving a frozen frame) and force a
    // fresh frame from the still-playing player.
    func refresh() {
        guard currentURL != nil else { return }
        for window in windows {
            window.orderFront(nil)
            window.playerView.rebuildPlayerLayer()
        }
        looper.forceCurrentFrame()
    }

    func setShowOnAllSpaces(_ enabled: Bool) {
        currentShowOnAllSpaces = enabled
        // rebuild so windows are re-created with the new collection behavior and re-ordered;
        // mutating collectionBehavior on an already-ordered window does not reliably re-apply.
        if currentURL != nil {
            rebuildWindows()
        }
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
            MainActor.assumeIsolated {
                self?.rebuildWindows()
                self?.onScreensChange?()
            }
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
            let window = WallpaperWindow(screen: screen, showOnAllSpaces: currentShowOnAllSpaces)
            window.playerView.bind(to: looper.player)
            window.playerView.setFitMode(currentFitMode)
            window.playerView.setDim(currentDim)
            window.orderFront(nil)
            return window
        }
    }
}
