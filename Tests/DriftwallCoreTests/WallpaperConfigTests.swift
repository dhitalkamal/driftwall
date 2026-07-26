import Foundation
import DriftwallCore

func runWallpaperConfigTests(_ t: TestRunner) {
    // a fresh config has no video, pauses on battery, fills the screen, no playlist, and no
    // per-display overrides.
    let defaults = WallpaperConfig()
    t.expectEqual(defaults.selectedVideo, nil)
    t.expectEqual(defaults.pauseOnBattery, true)
    t.expectEqual(defaults.hasVideo, false)
    t.expectEqual(defaults.fitMode, .fill)
    t.expectEqual(defaults.playlistEnabled, false)
    t.expect(defaults.playlist == nil, "no playlist by default")
    t.expect(defaults.perDisplayVideos.isEmpty, "no per-display overrides by default")
    t.expectEqual(defaults.playbackSettings, PlaybackSettings())
    // by default we take over the system wallpaper with a still stand-in so a Space switch
    // reveals a matching frame instead of a different desktop picture.
    t.expectEqual(defaults.replaceSystemWallpaper, true)
    // by default the wallpaper shows on every Space.
    t.expectEqual(defaults.showOnAllSpaces, true)

    // a fully populated config round-trips through json for persistence.
    let full = WallpaperConfig(
        selectedVideo: URL(fileURLWithPath: "/tmp/loop.mp4"),
        perDisplayVideos: ["display-1": URL(fileURLWithPath: "/tmp/a.mp4")],
        fitMode: .fit,
        playlist: Playlist(
            videos: [URL(fileURLWithPath: "/tmp/a.mp4"), URL(fileURLWithPath: "/tmp/b.mp4")],
            shuffle: true,
            intervalSeconds: 60
        ),
        playlistEnabled: true,
        playbackSettings: PlaybackSettings(volume: 0.4, dim: 0.2),
        pauseOnBattery: false,
        replaceSystemWallpaper: false,
        showOnAllSpaces: false
    )
    t.expectEqual(full.hasVideo, true)
    do {
        let decoded = try JSONDecoder().decode(WallpaperConfig.self, from: JSONEncoder().encode(full))
        t.expectEqual(decoded, full)
    } catch {
        t.expect(false, "config failed to round-trip through json: \(error)")
    }
}
