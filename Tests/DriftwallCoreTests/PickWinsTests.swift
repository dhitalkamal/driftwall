import Foundation
import DriftwallCore

private let picked = URL(fileURLWithPath: "/tmp/picked.mp4")
private let p0 = URL(fileURLWithPath: "/tmp/p0.mp4")
private let p1 = URL(fileURLWithPath: "/tmp/p1.mp4")
private let clear = EnvironmentSignals(isOccluded: false, isFullscreenAppFrontmost: false, isOnBattery: false)

// what the user picks is what plays, and the app always knows which video is on screen.
@MainActor
func runPickWinsTests(_ t: TestRunner) {
    // a one-video playlist cannot rotate, so it does not override the chosen video ...
    let oneItem = WallpaperConfig(selectedVideo: picked,
                                  playlist: Playlist(videos: [p0], shuffle: false, intervalSeconds: 60),
                                  playlistEnabled: true)
    t.expectEqual(WallpaperResolver.video(for: "d1", config: oneItem, playlistOrder: [0], playlistAdvance: 0), picked)
    // ... but it still plays when nothing else is chosen.
    var oneItemOnly = oneItem
    oneItemOnly.selectedVideo = nil
    t.expectEqual(WallpaperResolver.video(for: "d1", config: oneItemOnly, playlistOrder: [0], playlistAdvance: 0), p0)

    // choosing a video while a playlist rotates: the pick plays and rotation switches off.
    do {
        let store = FakeStore(WallpaperConfig(playlist: Playlist(videos: [p0, p1], shuffle: false, intervalSeconds: 60),
                                              playlistEnabled: true))
        let renderer = FakeRenderer()
        let controller = WallpaperController(store: store, renderer: renderer)
        var scheduleChanges = 0
        controller.onRotationScheduleChanged = { scheduleChanges += 1 }
        controller.start(environment: clear)
        t.expectEqual(renderer.lastShown, p0)
        scheduleChanges = 0

        controller.selectVideo(picked)
        t.expectEqual(renderer.lastShown, picked)
        t.expectEqual(controller.currentVideoURL, picked)
        t.expectEqual(store.stored.playlistEnabled, false)
        t.expectEqual(store.stored.playlist?.videos, [p0, p1])  // the playlist itself is kept
        t.expect(controller.rotationIntervalSeconds == nil, "rotation timer should stop")
        t.expect(scheduleChanges > 0, "the app must be told to stop its rotation timer")
    }

    // the current-video callback reports every change of what is on screen, once per change.
    do {
        let store = FakeStore(WallpaperConfig(selectedVideo: picked,
                                              playlist: Playlist(videos: [p0, p1], shuffle: false, intervalSeconds: 60),
                                              playlistEnabled: true))
        let controller = WallpaperController(store: store, renderer: FakeRenderer())
        var seen: [URL?] = []
        controller.onCurrentVideoChanged = { seen.append($0) }
        controller.start(environment: clear)
        controller.advancePlaylist()
        controller.advancePlaylist()
        controller.setFitMode(.fit)  // unrelated change: no report
        controller.clearVideo()
        t.expectEqual(seen, [p0, p1, p0, nil])
    }
}
