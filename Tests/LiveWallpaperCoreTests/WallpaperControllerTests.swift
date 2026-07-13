import Foundation
import LiveWallpaperCore

// records what the controller asks the wallpaper surface to do.
@MainActor
private final class FakeRenderer: WallpaperRendering {
    var shownVideos: [URL] = []
    var commands: [String] = []
    func show(video url: URL) { shownVideos.append(url) }
    func play() { commands.append("play") }
    func pause() { commands.append("pause") }
    func hide() { commands.append("hide") }
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
}
