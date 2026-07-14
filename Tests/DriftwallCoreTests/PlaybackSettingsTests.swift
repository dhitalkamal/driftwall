import Foundation
import DriftwallCore

func runPlaybackSettingsTests(_ t: TestRunner) {
    // defaults: full volume off (muted wallpaper by default), no dim, normal speed.
    let defaults = PlaybackSettings()
    t.expectEqual(defaults.volume, 0)
    t.expectEqual(defaults.dim, 0)
    t.expectEqual(defaults.speed, 1.0)

    // volume and dim are clamped to 0...1.
    t.expectEqual(PlaybackSettings(volume: 2.0, dim: -1.0).volume, 1.0)
    t.expectEqual(PlaybackSettings(volume: -0.5, dim: 5.0).dim, 1.0)
    t.expectEqual(PlaybackSettings(volume: 0.5, dim: 0.25).volume, 0.5)
    t.expectEqual(PlaybackSettings(volume: 0.5, dim: 0.25).dim, 0.25)

    // speed is clamped to 0.25...2.0.
    t.expectEqual(PlaybackSettings(speed: 5.0).speed, 2.0)
    t.expectEqual(PlaybackSettings(speed: 0.0).speed, 0.25)
    t.expectEqual(PlaybackSettings(speed: 1.5).speed, 1.5)

    // round-trips through json.
    do {
        let s = PlaybackSettings(volume: 0.3, dim: 0.7, speed: 1.75)
        let decoded = try JSONDecoder().decode(PlaybackSettings.self, from: JSONEncoder().encode(s))
        t.expectEqual(decoded, s)
    } catch {
        t.expect(false, "playback settings failed to round-trip: \(error)")
    }
}
