import Foundation
import DriftwallCore

// records what the controller asks the wallpaper surface to do.
@MainActor
private final class FakeRenderer: WallpaperRendering {
    var shownVideos: [URL] = []
    var commands: [String] = []
    var fitMode: FitMode?
    var volume: Double?
    var dim: Double?
    var showOnAllSpaces: Bool?
    var refreshCount = 0
    var events: [String] = []
    func refresh() { refreshCount += 1 }
    func show(video url: URL) { shownVideos.append(url); events.append("show") }
    func play() { commands.append("play") }
    func pause() { commands.append("pause") }
    func hide() { commands.append("hide"); events.append("hide") }
    func setFitMode(_ mode: FitMode) { fitMode = mode }
    func setVolume(_ volume: Double) { self.volume = volume }
    func setDim(_ dim: Double) { self.dim = dim }
    func setShowOnAllSpaces(_ enabled: Bool) { showOnAllSpaces = enabled; events.append("spaces:\(enabled)") }
    var lastCommand: String? { commands.last }
}

@MainActor
private final class FakeStore: ConfigStoring {
    var stored: WallpaperConfig
    var saveCount = 0
    init(_ config: WallpaperConfig = WallpaperConfig()) { stored = config }
    func load() -> WallpaperConfig { stored }
    func save(_ config: WallpaperConfig) { stored = config; saveCount += 1 }
}

@MainActor
private final class FakeSystemWallpaper: SystemWallpaperControlling {
    var takeOverCount = 0
    var restoreCount = 0
    var standInVideos: [URL?] = []
    func setStandIn(forVideo url: URL?) { standInVideos.append(url) }
    func takeOver() { takeOverCount += 1 }
    func restore() { restoreCount += 1 }
}

private let clearEnv = EnvironmentSignals(
    isOccluded: false,
    isFullscreenAppFrontmost: false,
    isOnBattery: false
)

private let sampleVideo = URL(fileURLWithPath: "/tmp/loop.mp4")

@MainActor
func runWallpaperControllerTests(_ t: TestRunner) {
    // start with a saved video in clear conditions: shows the video and plays it.
    do {
        let store = FakeStore(WallpaperConfig(selectedVideo: sampleVideo))
        let renderer = FakeRenderer()
        let controller = WallpaperController(store: store, renderer: renderer)
        controller.start(environment: clearEnv)
        t.expectEqual(renderer.shownVideos, [sampleVideo])
        t.expectEqual(renderer.lastCommand, "play")
    }

    // start with no saved video: does not show anything and does not play.
    do {
        let store = FakeStore(WallpaperConfig())
        let renderer = FakeRenderer()
        let controller = WallpaperController(store: store, renderer: renderer)
        controller.start(environment: clearEnv)
        t.expectEqual(renderer.shownVideos, [])
        t.expect(renderer.commands.contains("play") == false, "should not play without a video")
    }

    // selecting a video persists config, shows it, and plays under clear conditions.
    do {
        let store = FakeStore(WallpaperConfig())
        let renderer = FakeRenderer()
        let controller = WallpaperController(store: store, renderer: renderer)
        controller.start(environment: clearEnv)
        controller.selectVideo(sampleVideo)
        t.expectEqual(store.stored.selectedVideo, sampleVideo)
        t.expect(store.saveCount >= 1, "selecting a video should persist config")
        t.expectEqual(renderer.shownVideos, [sampleVideo])
        t.expectEqual(renderer.lastCommand, "play")
    }

    // environment change to occluded pauses, and back to clear resumes.
    do {
        let store = FakeStore(WallpaperConfig(selectedVideo: sampleVideo))
        let renderer = FakeRenderer()
        let controller = WallpaperController(store: store, renderer: renderer)
        controller.start(environment: clearEnv)
        controller.updateEnvironment(EnvironmentSignals(
            isOccluded: true, isFullscreenAppFrontmost: false, isOnBattery: false))
        t.expectEqual(renderer.lastCommand, "pause")
        controller.updateEnvironment(clearEnv)
        t.expectEqual(renderer.lastCommand, "play")
    }

    // toggling pause-on-battery off keeps playing while on battery; on pauses.
    do {
        let store = FakeStore(WallpaperConfig(selectedVideo: sampleVideo, pauseOnBattery: true))
        let renderer = FakeRenderer()
        let controller = WallpaperController(store: store, renderer: renderer)
        controller.start(environment: EnvironmentSignals(
            isOccluded: false, isFullscreenAppFrontmost: false, isOnBattery: true))
        t.expectEqual(renderer.lastCommand, "pause")
        controller.setPauseOnBattery(false)
        t.expectEqual(renderer.lastCommand, "play")
        t.expectEqual(store.stored.pauseOnBattery, false)
    }

    // showing a video applies the saved appearance settings to the renderer.
    do {
        let config = WallpaperConfig(
            selectedVideo: sampleVideo,
            fitMode: .fit,
            playbackSettings: PlaybackSettings(volume: 0.6, dim: 0.3)
        )
        let store = FakeStore(config)
        let renderer = FakeRenderer()
        let controller = WallpaperController(store: store, renderer: renderer)
        controller.start(environment: clearEnv)
        t.expectEqual(renderer.fitMode, .fit)
        t.expectEqual(renderer.volume, 0.6)
        t.expectEqual(renderer.dim, 0.3)
    }

    // changing fit mode and playback settings persists and pushes to the renderer.
    do {
        let store = FakeStore(WallpaperConfig(selectedVideo: sampleVideo))
        let renderer = FakeRenderer()
        let controller = WallpaperController(store: store, renderer: renderer)
        controller.start(environment: clearEnv)
        controller.setFitMode(.stretch)
        controller.setPlaybackSettings(PlaybackSettings(volume: 0.2, dim: 0.9))
        t.expectEqual(renderer.fitMode, .stretch)
        t.expectEqual(renderer.volume, 0.2)
        t.expectEqual(renderer.dim, 0.9)
        t.expectEqual(store.stored.fitMode, .stretch)
        t.expectEqual(store.stored.playbackSettings.volume, 0.2)
    }

    // with replaceSystemWallpaper on, showing a video takes over the system wallpaper once,
    // and clearing the video restores it.
    do {
        let store = FakeStore(WallpaperConfig(selectedVideo: sampleVideo, replaceSystemWallpaper: true))
        let system = FakeSystemWallpaper()
        let controller = WallpaperController(
            store: store, renderer: FakeRenderer(), systemWallpaper: system)
        controller.start(environment: clearEnv)
        t.expectEqual(system.takeOverCount, 1)
        // an unrelated refresh (env change) must not take over again.
        controller.updateEnvironment(clearEnv)
        t.expectEqual(system.takeOverCount, 1)
        controller.clearVideo()
        t.expectEqual(system.restoreCount, 1)
    }

    // with replaceSystemWallpaper off, showing a video never touches the system wallpaper.
    do {
        let store = FakeStore(WallpaperConfig(selectedVideo: sampleVideo, replaceSystemWallpaper: false))
        let system = FakeSystemWallpaper()
        let controller = WallpaperController(
            store: store, renderer: FakeRenderer(), systemWallpaper: system)
        controller.start(environment: clearEnv)
        t.expectEqual(system.takeOverCount, 0)
    }

    // toggling the setting off while active restores immediately; back on takes over again.
    do {
        let store = FakeStore(WallpaperConfig(selectedVideo: sampleVideo, replaceSystemWallpaper: true))
        let system = FakeSystemWallpaper()
        let controller = WallpaperController(
            store: store, renderer: FakeRenderer(), systemWallpaper: system)
        controller.start(environment: clearEnv)
        controller.setReplaceSystemWallpaper(false)
        t.expectEqual(system.restoreCount, 1)
        controller.setReplaceSystemWallpaper(true)
        t.expectEqual(system.takeOverCount, 2)
    }

    // showing a video pushes the show-on-all-spaces setting; toggling it persists and pushes.
    do {
        let store = FakeStore(WallpaperConfig(selectedVideo: sampleVideo, showOnAllSpaces: true))
        let renderer = FakeRenderer()
        let controller = WallpaperController(store: store, renderer: renderer)
        controller.start(environment: clearEnv)
        t.expectEqual(renderer.showOnAllSpaces, true)
        controller.setShowOnAllSpaces(false)
        t.expectEqual(renderer.showOnAllSpaces, false)
        t.expectEqual(store.stored.showOnAllSpaces, false)
    }

    // returning to a Space re-evaluates playback (resume) and forces a fresh frame so a
    // long-off-screen video layer repaints instead of staying black.
    do {
        let store = FakeStore(WallpaperConfig(selectedVideo: sampleVideo))
        let renderer = FakeRenderer()
        let controller = WallpaperController(store: store, renderer: renderer)
        controller.start(environment: clearEnv)
        // simulate being covered on another Space, then returning.
        controller.updateEnvironment(EnvironmentSignals(
            isOccluded: true, isFullscreenAppFrontmost: false, isOnBattery: false))
        t.expectEqual(renderer.lastCommand, "pause")
        let refreshesBefore = renderer.refreshCount
        controller.updateEnvironment(clearEnv)   // occlusion cleared
        controller.handleSpaceChanged()
        t.expectEqual(renderer.lastCommand, "play")
        t.expect(renderer.refreshCount > refreshesBefore, "space change should force a refresh")
    }

    // a space change while nothing is showing does nothing.
    do {
        let store = FakeStore(WallpaperConfig())
        let renderer = FakeRenderer()
        let controller = WallpaperController(store: store, renderer: renderer)
        controller.start(environment: clearEnv)
        controller.handleSpaceChanged()
        t.expectEqual(renderer.refreshCount, 0)
    }

    // restoreSystemWallpaper (called on quit) restores once and is idempotent.
    do {
        let store = FakeStore(WallpaperConfig(selectedVideo: sampleVideo, replaceSystemWallpaper: true))
        let system = FakeSystemWallpaper()
        let controller = WallpaperController(
            store: store, renderer: FakeRenderer(), systemWallpaper: system)
        controller.start(environment: clearEnv)
        controller.restoreSystemWallpaper()
        controller.restoreSystemWallpaper()
        t.expectEqual(system.restoreCount, 1)
    }

    // showing a video sets the system stand-in to that video (for a seamless frame instead of
    // black); clearing the video sets the stand-in back to nil.
    do {
        let store = FakeStore(WallpaperConfig(selectedVideo: sampleVideo, replaceSystemWallpaper: true))
        let system = FakeSystemWallpaper()
        let controller = WallpaperController(
            store: store, renderer: FakeRenderer(), systemWallpaper: system)
        controller.start(environment: clearEnv)
        t.expectEqual(system.standInVideos.last ?? nil, Optional(sampleVideo))
        controller.clearVideo()
        if case .some(let last) = system.standInVideos.last {
            t.expect(last == nil, "clearing the video resets the stand-in to nil")
        } else {
            t.expect(false, "setStandIn should have been called on clear")
        }
    }

    // a screen change re-runs takeover so a hot-plugged display gets covered (takeOver is
    // additive), but only while active with the setting on.
    do {
        let store = FakeStore(WallpaperConfig(selectedVideo: sampleVideo, replaceSystemWallpaper: true))
        let system = FakeSystemWallpaper()
        let controller = WallpaperController(
            store: store, renderer: FakeRenderer(), systemWallpaper: system)
        controller.start(environment: clearEnv)
        t.expectEqual(system.takeOverCount, 1)
        controller.handleScreensChanged()
        t.expectEqual(system.takeOverCount, 2)
    }
    do {
        let store = FakeStore(WallpaperConfig(selectedVideo: sampleVideo, replaceSystemWallpaper: false))
        let system = FakeSystemWallpaper()
        let controller = WallpaperController(
            store: store, renderer: FakeRenderer(), systemWallpaper: system)
        controller.start(environment: clearEnv)
        controller.handleScreensChanged()
        t.expectEqual(system.takeOverCount, 0)
    }

    // on start, the renderer is told the all-spaces setting before the video is shown, so
    // windows are created with the correct collection behavior.
    do {
        let store = FakeStore(WallpaperConfig(selectedVideo: sampleVideo, showOnAllSpaces: false))
        let renderer = FakeRenderer()
        let controller = WallpaperController(store: store, renderer: renderer)
        controller.start(environment: clearEnv)
        let spacesIndex = renderer.events.firstIndex(of: "spaces:false")
        let showIndex = renderer.events.firstIndex(of: "show")
        t.expect(spacesIndex != nil && showIndex != nil, "both events should fire")
        if let s = spacesIndex, let sh = showIndex {
            t.expect(s < sh, "show-on-all-spaces should be set before show")
        }
    }
}
