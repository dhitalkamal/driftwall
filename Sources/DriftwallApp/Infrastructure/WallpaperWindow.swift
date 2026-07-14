import AppKit
import AVFoundation
import DriftwallCore

// a layer-backed view hosting a swappable AVPlayerLayer with a black dim overlay on top. the
// AVPlayerLayer is a sublayer (not the backing layer) so it can be rebuilt in place: when a
// window has been off a non-active Space for a while its GPU surface is reclaimed and the old
// layer stops compositing (frozen frame), so on Space return we install a fresh layer bound to
// the still-playing player, which composites live video again.
final class PlayerView: NSView {
    private var playerLayer: AVPlayerLayer?
    private let dimLayer = CALayer()
    private weak var boundPlayer: AVPlayer?
    private var gravity: AVLayerVideoGravity = .resizeAspectFill

    override func makeBackingLayer() -> CALayer { CALayer() }

    func bind(to player: AVPlayer) {
        wantsLayer = true
        boundPlayer = player
        dimLayer.backgroundColor = NSColor.black.cgColor
        rebuildPlayerLayer()
    }

    // install a fresh AVPlayerLayer surface, preserving fit and dim. safe to call repeatedly.
    func rebuildPlayerLayer() {
        guard let hostLayer = layer else { return }
        playerLayer?.removeFromSuperlayer()
        dimLayer.removeFromSuperlayer()

        let newLayer = AVPlayerLayer()
        newLayer.videoGravity = gravity
        newLayer.frame = bounds
        newLayer.player = boundPlayer
        hostLayer.addSublayer(newLayer)
        playerLayer = newLayer

        dimLayer.frame = bounds
        hostLayer.addSublayer(dimLayer)  // keep dim on top
    }

    func setFitMode(_ mode: FitMode) {
        gravity = mode.videoGravity
        playerLayer?.videoGravity = gravity
    }

    func setDim(_ dim: Double) {
        dimLayer.opacity = Float(min(1, max(0, dim)))
    }

    override func layout() {
        super.layout()
        // keep the video and dim layers covering the whole view as it resizes.
        playerLayer?.frame = bounds
        dimLayer.frame = bounds
    }
}

extension FitMode {
    var videoGravity: AVLayerVideoGravity {
        switch self {
        case .fill: return .resizeAspectFill
        case .fit: return .resizeAspect
        case .stretch: return .resize
        }
    }
}

// a borderless window pinned to the desktop window level so it renders behind the desktop
// icons, spans one screen, ignores input, and stays put in Mission Control. the level and
// collection-behavior recipe is the standard (unofficial) technique for macOS live wallpapers.
final class WallpaperWindow: NSWindow {
    let playerView = PlayerView()

    init(screen: NSScreen, showOnAllSpaces: Bool) {
        super.init(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        // desktopWindow level sits above the static desktop picture but below the icons.
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)))
        setShowOnAllSpaces(showOnAllSpaces)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true
        hidesOnDeactivate = false
        // a borderless window cannot be key/main, which is exactly what we want.
        contentView = playerView
        setFrame(screen.frame, display: true)
    }

    // stationary is mandatory: a non-normal window level otherwise defaults to transient and
    // vanishes in Mission Control. ignoresCycle removes it from Cycle Through Windows.
    // canJoinAllSpaces makes it appear on every Space when enabled.
    func setShowOnAllSpaces(_ enabled: Bool) {
        var behavior: NSWindow.CollectionBehavior = [.stationary, .ignoresCycle]
        if enabled {
            behavior.insert(.canJoinAllSpaces)
        }
        collectionBehavior = behavior
    }
}
