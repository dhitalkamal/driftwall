import Foundation

// ports the application layer depends on. infrastructure adapters implement these; the
// domain and application never import AppKit/AVFoundation directly.

// renders the wallpaper video behind the desktop icons. an adapter typically manages one
// borderless window per screen plus a shared looping player. main-actor isolated because
// the AppKit/AVFoundation adapters that implement it must run on the main thread.
@MainActor
public protocol WallpaperRendering: AnyObject {
    // create or refresh the wallpaper surface and load the given video.
    func show(video url: URL)
    func play()
    func pause()
    // tear the wallpaper surface down (no video selected).
    func hide()
    // how the video is scaled to the display.
    func setFitMode(_ mode: FitMode)
    // audio volume, 0...1. 0 mutes.
    func setVolume(_ volume: Double)
    // dim overlay strength, 0...1. 0 is no dim, 1 is fully black.
    func setDim(_ dim: Double)
}

// loads and persists the user's wallpaper settings.
@MainActor
public protocol ConfigStoring: AnyObject {
    func load() -> WallpaperConfig
    func save(_ config: WallpaperConfig)
}
