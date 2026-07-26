import Foundation
import DriftwallCore

func runWallpaperResolverTests(_ t: TestRunner) {
    let single = URL(fileURLWithPath: "/tmp/single.mp4")
    let perA = URL(fileURLWithPath: "/tmp/a.mp4")
    let p0 = URL(fileURLWithPath: "/tmp/p0.mp4")
    let p1 = URL(fileURLWithPath: "/tmp/p1.mp4")

    // with no per-display override or playlist, every display gets the single video.
    let singleOnly = WallpaperConfig(selectedVideo: single)
    t.expectEqual(
        WallpaperResolver.video(for: "d1", config: singleOnly,
                                playlistOrder: [], playlistAdvance: 0),
        single
    )

    // a per-display override returns that override for its display, and the single video for
    // any display without one.
    let perDisplay = WallpaperConfig(selectedVideo: single, perDisplayVideos: ["d1": perA])
    t.expectEqual(
        WallpaperResolver.video(for: "d1", config: perDisplay,
                                playlistOrder: [], playlistAdvance: 0),
        perA
    )
    t.expectEqual(
        WallpaperResolver.video(for: "d2", config: perDisplay,
                                playlistOrder: [], playlistAdvance: 0),
        single
    )

    // an enabled playlist takes precedence over per-display overrides and rotates by advance.
    let playlistConfig = WallpaperConfig(
        selectedVideo: single,
        perDisplayVideos: ["d1": perA],
        playlist: Playlist(videos: [p0, p1], shuffle: false, intervalSeconds: 30),
        playlistEnabled: true
    )
    t.expectEqual(
        WallpaperResolver.video(for: "d1", config: playlistConfig,
                                playlistOrder: [0, 1], playlistAdvance: 0),
        p0
    )
    t.expectEqual(
        WallpaperResolver.video(for: "d1", config: playlistConfig,
                                playlistOrder: [0, 1], playlistAdvance: 1),
        p1
    )
}
