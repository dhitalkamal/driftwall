import AppKit

// the menu-bar status-item glyph: three stacked "drift" waves echoing the app icon, drawn as a
// monochrome template image so macOS tints it for light/dark menu bars.
enum MenuBarIcon {
    // active: solid strokes while the wallpaper is playing; dimmed when paused/idle.
    static func make(active: Bool = false) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            ctx.setStrokeColor(NSColor.black.withAlphaComponent(active ? 0.9 : 0.4).cgColor)
            ctx.setLineWidth(1.4)
            ctx.setLineCap(.round)
            ctx.setLineJoin(.round)

            let insetX: CGFloat = 2.5
            let span = rect.width - insetX * 2
            let amplitude: CGFloat = 1.3
            for y in [CGFloat(5), 9, 13] {
                let path = CGMutablePath()
                path.move(to: CGPoint(x: insetX, y: y))
                var x = insetX
                while x <= rect.width - insetX {
                    let phase = (x - insetX) / span * .pi * 2
                    path.addLine(to: CGPoint(x: x, y: y + sin(phase) * amplitude))
                    x += 0.5
                }
                ctx.addPath(path)
            }
            ctx.strokePath()
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Driftwall"
        return image
    }
}
