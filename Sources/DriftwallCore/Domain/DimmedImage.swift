import CoreGraphics

// darkens an image the same way the wallpaper window's dim overlay does: black at `dim`
// opacity over the picture, so every channel becomes value x (1 - dim). used for the desktop
// stand-in, which macOS shows under the menu bar and during Space switches.
public enum DimmedImage {
    // nil only if a drawing context cannot be created for the image.
    public static func make(_ image: CGImage, dim: Double) -> CGImage? {
        let amount = min(1, max(0, dim))
        guard amount > 0 else { return image }
        guard let ctx = CGContext(
            data: nil, width: image.width, height: image.height, bitsPerComponent: 8,
            bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        let rect = CGRect(x: 0, y: 0, width: image.width, height: image.height)
        ctx.draw(image, in: rect)
        ctx.setFillColor(CGColor(gray: 0, alpha: amount))
        ctx.fill(rect)
        return ctx.makeImage()
    }
}
