import AppKit
import AVFoundation
import DriftwallCore

// a layer-backed view whose backing layer is an AVPlayerLayer, with a black dim overlay
// sublayer on top. the video fills the view and resizes with it; the dim layer tracks bounds.
final class PlayerView: NSView {
    private let dimLayer = CALayer()

    override func makeBackingLayer() -> CALayer {
        let layer = AVPlayerLayer()
        layer.videoGravity = .resizeAspectFill
        return layer
    }

    var playerLayer: AVPlayerLayer? {
        layer as? AVPlayerLayer
    }

    func bind(to player: AVPlayer) {
        wantsLayer = true
        playerLayer?.player = player
        dimLayer.backgroundColor = NSColor.black.cgColor
        dimLayer.opacity = 0
        dimLayer.frame = bounds
        playerLayer?.addSublayer(dimLayer)
    }

    func setFitMode(_ mode: FitMode) {
        playerLayer?.videoGravity = mode.videoGravity
    }

    func setDim(_ dim: Double) {
        dimLayer.opacity = Float(min(1, max(0, dim)))
    }

    override func layout() {
        super.layout()
        // keep the dim overlay covering the whole view as it resizes.
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

    init(screen: NSScreen) {
        super.init(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        // desktopWindow level sits above the static desktop picture but below the icons.
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)))
        // canJoinAllSpaces keeps it on every Space; stationary is mandatory because a
        // non-normal window level otherwise defaults to transient and vanishes in Mission
        // Control; ignoresCycle removes it from Cycle Through Windows.
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true
        hidesOnDeactivate = false
        // a borderless window cannot be key/main, which is exactly what we want.
        contentView = playerView
        setFrame(screen.frame, display: true)
    }
}
