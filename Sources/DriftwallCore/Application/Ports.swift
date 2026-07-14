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
    // playback speed multiplier (1.0 = normal).
    func setSpeed(_ rate: Double)
    // whether the wallpaper window joins every Space.
    func setShowOnAllSpaces(_ enabled: Bool)
    // re-assert the wallpaper windows and force the video to present a fresh frame. called on
    // Space changes / resume so a reclaimed GPU surface repaints instead of staying black.
    func refresh()
}

// loads and persists the user's wallpaper settings.
@MainActor
public protocol ConfigStoring: AnyObject {
    func load() -> WallpaperConfig
    func save(_ config: WallpaperConfig)
}

// takes over the macOS desktop picture while our wallpaper is active (so the system animates
// nothing behind us) and restores it afterwards. the adapter uses NSWorkspace.
@MainActor
public protocol SystemWallpaperControlling: AnyObject {
    // tell the controller which video is active so it can use a still frame of that video as
    // the desktop stand-in (seamless Space transitions) instead of solid black. pass nil when
    // no video is shown.
    func setStandIn(forVideo url: URL?)
    func takeOver()
    func restore()
}

// default no-op used when the caller does not supply a real controller (e.g. in tests that
// do not exercise system-wallpaper behavior).
@MainActor
public final class NoopSystemWallpaper: SystemWallpaperControlling {
    public init() {}
    public func setStandIn(forVideo url: URL?) {}
    public func takeOver() {}
    public func restore() {}
}
