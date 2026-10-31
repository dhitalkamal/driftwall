import CoreGraphics
import Foundation
import DriftwallCore

// a solid grey test image of the given brightness (0-255).
private func grey(_ value: UInt8) -> CGImage {
    let w = 4, h = 4
    var pixels = [UInt8](repeating: 255, count: w * h * 4)
    for i in stride(from: 0, to: pixels.count, by: 4) { pixels[i] = value; pixels[i + 1] = value; pixels[i + 2] = value }
    let ctx = CGContext(data: &pixels, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    return ctx.makeImage()!
}

// red channel of the first pixel.
private func red(_ image: CGImage?) -> Int {
    guard let image else { return -1 }
    var pixel = [UInt8](repeating: 0, count: 4)
    let ctx = CGContext(data: &pixel, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.draw(image, in: CGRect(x: 0, y: 0, width: 1, height: 1))
    return Int(pixel[0])
}

@MainActor
func runDimStandInTests(_ t: TestRunner) {
    // the desktop stand-in is darkened exactly like the window's black overlay: value x (1 - dim).
    t.expectEqual(red(DimmedImage.make(grey(200), dim: 0)), 200)
    t.expect(abs(red(DimmedImage.make(grey(200), dim: 0.6)) - 80) <= 1, "60% dim of 200 should be about 80")
    t.expectEqual(red(DimmedImage.make(grey(200), dim: 1)), 0)
    // out-of-range dims clamp instead of brightening or going negative.
    t.expectEqual(red(DimmedImage.make(grey(200), dim: -0.5)), 200)
    t.expectEqual(red(DimmedImage.make(grey(200), dim: 3)), 0)

    // the controller hands the dim to the desktop stand-in at start and whenever it changes.
    let store = FakeStore(WallpaperConfig(selectedVideo: URL(fileURLWithPath: "/tmp/loop.mp4"),
                                          playbackSettings: PlaybackSettings(dim: 0.6)))
    let system = FakeSystemWallpaper()
    let controller = WallpaperController(store: store, renderer: FakeRenderer(), systemWallpaper: system)
    controller.start(environment: EnvironmentSignals(isOccluded: false, isFullscreenAppFrontmost: false, isOnBattery: false))
    t.expectEqual(system.dims.last, 0.6)
    controller.setPlaybackSettings(PlaybackSettings(dim: 0.25))
    t.expectEqual(system.dims.last, 0.25)
}
