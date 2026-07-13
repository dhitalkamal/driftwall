import AppKit
import AVFoundation

// a layer-backed view whose backing layer is an AVPlayerLayer, so the video fills the view
// and resizes with it automatically.
final class PlayerView: NSView {
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
