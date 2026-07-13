import Foundation
import DriftwallCore

func runWallpaperConfigTests(_ t: TestRunner) {
    // a fresh config has no video and pauses on battery.
    let defaults = WallpaperConfig()
    t.expectEqual(defaults.selectedVideo, nil)
    t.expectEqual(defaults.pauseOnBattery, true)
    t.expectEqual(defaults.hasVideo, false)

    // hasVideo reflects whether a video url is set.
    let withVideo = WallpaperConfig(
        selectedVideo: URL(fileURLWithPath: "/tmp/loop.mp4"),
        pauseOnBattery: false
    )
    t.expectEqual(withVideo.hasVideo, true)

    // config round-trips through json so it can be persisted and reloaded.
    do {
        let encoded = try JSONEncoder().encode(withVideo)
        let decoded = try JSONDecoder().decode(WallpaperConfig.self, from: encoded)
        t.expectEqual(decoded, withVideo)
    } catch {
        t.expect(false, "config failed to round-trip through json: \(error)")
    }
}
