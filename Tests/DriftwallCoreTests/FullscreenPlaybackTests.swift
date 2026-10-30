import Foundation
import DriftwallCore

private let video = URL(fileURLWithPath: "/tmp/loop.mp4")

private let clear = EnvironmentSignals(
    isOccluded: false, isFullscreenAppFrontmost: false, isOnBattery: false)
// fullscreen app frontmost on one display, wallpaper still visible on another.
private let partialFullscreen = EnvironmentSignals(
    isOccluded: false, isFullscreenAppFrontmost: true, isOnBattery: false)
// fullscreen app covering every display.
private let fullFullscreen = EnvironmentSignals(
    isOccluded: false, isFullscreenAppFrontmost: true, isOnBattery: false,
    isFullscreenOnEveryDisplay: true)

@MainActor
private func makeController(
    volume: Double = 0.6, behavior: FullscreenBehavior = .muteAudio
) -> (WallpaperController, FakeRenderer, FakeStore) {
    let store = FakeStore(WallpaperConfig(
        selectedVideo: video,
        playbackSettings: PlaybackSettings(volume: volume),
        fullscreenBehavior: behavior))
    let renderer = FakeRenderer()
    let controller = WallpaperController(store: store, renderer: renderer)
    controller.start(environment: clear)
    return (controller, renderer, store)
}

@MainActor
func runFullscreenPlaybackTests(_ t: TestRunner) {
    // partial fullscreen with mute-only: keeps playing, silences audio, saved volume untouched.
    do {
        let (controller, renderer, store) = makeController()
        controller.updateEnvironment(partialFullscreen)
        t.expectEqual(renderer.lastCommand, "play")
        t.expectEqual(renderer.volume, 0)
        t.expectEqual(store.stored.playbackSettings.volume, 0.6)

        // leaving fullscreen restores the user's volume.
        controller.updateEnvironment(clear)
        t.expectEqual(renderer.lastCommand, "play")
        t.expectEqual(renderer.volume, 0.6)
    }

    // changing volume while muted saves it but keeps audio silent until fullscreen ends.
    do {
        let (controller, renderer, store) = makeController()
        controller.updateEnvironment(partialFullscreen)
        controller.setPlaybackSettings(PlaybackSettings(volume: 0.9))
        t.expectEqual(renderer.volume, 0)
        t.expectEqual(store.stored.playbackSettings.volume, 0.9)
        controller.updateEnvironment(clear)
        t.expectEqual(renderer.volume, 0.9)
    }

    // switching videos while muted does not leak audio through the fresh surface.
    do {
        let (controller, renderer, _) = makeController()
        controller.updateEnvironment(partialFullscreen)
        controller.selectVideo(URL(fileURLWithPath: "/tmp/other.mp4"))
        t.expectEqual(renderer.volume, 0)
    }

    // partial fullscreen with pause-everything: pauses.
    do {
        let (controller, renderer, _) = makeController(behavior: .pauseAll)
        controller.updateEnvironment(partialFullscreen)
        t.expectEqual(renderer.lastCommand, "pause")
        controller.updateEnvironment(clear)
        t.expectEqual(renderer.lastCommand, "play")
        t.expectEqual(renderer.volume, 0.6)
    }

    // fullscreen covering every display pauses even in mute-only mode.
    do {
        let (controller, renderer, _) = makeController()
        controller.updateEnvironment(fullFullscreen)
        t.expectEqual(renderer.lastCommand, "pause")
    }

    // changing the setting persists it and re-applies the decision immediately.
    do {
        let (controller, renderer, store) = makeController()
        controller.updateEnvironment(partialFullscreen)
        controller.setFullscreenBehavior(.pauseAll)
        t.expectEqual(store.stored.fullscreenBehavior, .pauseAll)
        t.expectEqual(renderer.lastCommand, "pause")
        controller.setFullscreenBehavior(.muteAudio)
        t.expectEqual(renderer.lastCommand, "play")
        t.expectEqual(renderer.volume, 0)
    }
}
