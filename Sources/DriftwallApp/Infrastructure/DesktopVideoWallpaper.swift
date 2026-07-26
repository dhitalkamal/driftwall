import AppKit
import AVFoundation
import CoreImage
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
    // blurred fill still shown behind a letterboxed (Fit) video, and the video it was made from.
    private var currentBlur: CGImage?
    private var blurSourceURL: URL?

    // CGImage is immutable/thread-safe; box it to carry across the actor boundary from the
    // background generation task without a Sendable warning.
    private struct SendableCGImage: @unchecked Sendable { let image: CGImage }

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
        ) { note in
            // the observer runs on the main queue; capture a Sendable identity (not the window)
            // so the main-actor hop below is data-race clean.
            let changedWindow = (note.object as? NSWindow).map(ObjectIdentifier.init)
            MainActor.assumeIsolated {
                // only our wallpaper windows affect wallpaper visibility; ignore occlusion
                // changes from unrelated windows such as the Preferences panel.
                guard let changedWindow,
                      self.windows.contains(where: { ObjectIdentifier($0) == changedWindow })
                else { return }
                self.onOcclusionChange?()
            }
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
        refreshBlurBackground(for: url)
    }

    // (re)generate the blurred fill still when the video changes, and apply it to the windows.
    private func refreshBlurBackground(for url: URL) {
        guard blurSourceURL != url else {
            applyBlurToWindows()
            return
        }
        blurSourceURL = url
        currentBlur = nil
        applyBlurToWindows()  // clear to black while the new blur generates
        Task {
            let result = await Self.generateBlur(for: url)
            await MainActor.run { [weak self] in
                guard let self, self.blurSourceURL == url else { return }
                self.currentBlur = result?.image
                self.applyBlurToWindows()
            }
        }
    }

    private func applyBlurToWindows() {
        for window in windows { window.playerView.setBackgroundImage(currentBlur) }
    }

    // extract a small early frame and heavily blur it. the source is capped small because the
    // blur destroys detail anyway, keeping this one-shot per-video cost cheap.
    private nonisolated static func generateBlur(for url: URL) async -> SendableCGImage? {
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 640, height: 640)
        guard let frame = try? await generator.image(at: CMTime(seconds: 0.1, preferredTimescale: 600)) else {
            return nil
        }
        let source = CIImage(cgImage: frame.image)
        let blurred = source.clampedToExtent()
            .applyingGaussianBlur(sigma: 24)
            .cropped(to: source.extent)
        guard let cg = CIContext().createCGImage(blurred, from: source.extent) else { return nil }
        return SendableCGImage(image: cg)
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

    // called on Space return: install fresh AVPlayerLayer surfaces (the old ones stop
    // compositing after being off a non-active Space, leaving a frozen frame) and force a
    // fresh frame from the still-playing player.
    func refresh() {
        guard currentURL != nil else { return }
        for window in windows {
            window.orderFront(nil)
            // when showing on all Spaces the windows never leave the active Space, so their GPU
            // surfaces are not reclaimed; rebuilding the layer there is pure churn and briefly
            // detaches the player. only rebuild (and re-assert appearance, since a fresh layer
            // defaults to fill) when windows actually go off-Space and can return frozen/black.
            if !currentShowOnAllSpaces {
                window.playerView.rebuildPlayerLayer()
                window.playerView.setFitMode(currentFitMode)
                window.playerView.setDim(currentDim)
            }
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
        currentBlur = nil
        blurSourceURL = nil
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
            window.playerView.setBackgroundImage(currentBlur)
            window.orderFront(nil)
            return window
        }
    }
}
