import Foundation
import DriftwallCore

func runWallpaperResolverTests(_ t: TestRunner) {
    let single = URL(fileURLWithPath: "/tmp/single.mp4")
    let perA = URL(fileURLWithPath: "/tmp/a.mp4")
    let p0 = URL(fileURLWithPath: "/tmp/p0.mp4")
    let p1 = URL(fileURLWithPath: "/tmp/p1.mp4")

    // free tier ignores per-display overrides and playlists, always the single video.
    let freeConfig = WallpaperConfig(
        selectedVideo: single,
        perDisplayVideos: ["d1": perA],
        playlist: Playlist(videos: [p0, p1], shuffle: false, intervalSeconds: 30),
        playlistEnabled: true
    )
    t.expectEqual(
        WallpaperResolver.video(for: "d1", config: freeConfig, tier: .free,
                                playlistOrder: [0, 1], playlistAdvance: 1),
        single
    )

    // pro tier with a per-display override returns that override for the display.
    let proConfig = WallpaperConfig(
        selectedVideo: single,
        perDisplayVideos: ["d1": perA]
    )
    t.expectEqual(
        WallpaperResolver.video(for: "d1", config: proConfig, tier: .pro,
                                playlistOrder: [], playlistAdvance: 0),
        perA
    )
    // a display without an override falls back to the single video.
    t.expectEqual(
        WallpaperResolver.video(for: "d2", config: proConfig, tier: .pro,
                                playlistOrder: [], playlistAdvance: 0),
        single
    )

    // pro tier with an enabled playlist takes precedence and rotates by advance count.
    let playlistConfig = WallpaperConfig(
        selectedVideo: single,
        perDisplayVideos: ["d1": perA],
        playlist: Playlist(videos: [p0, p1], shuffle: false, intervalSeconds: 30),
        playlistEnabled: true
    )
    t.expectEqual(
        WallpaperResolver.video(for: "d1", config: playlistConfig, tier: .pro,
                                playlistOrder: [0, 1], playlistAdvance: 0),
        p0
    )
    t.expectEqual(
        WallpaperResolver.video(for: "d1", config: playlistConfig, tier: .pro,
                                playlistOrder: [0, 1], playlistAdvance: 1),
        p1
    )
}
