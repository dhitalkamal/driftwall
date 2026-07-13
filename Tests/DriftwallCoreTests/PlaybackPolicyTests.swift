import DriftwallCore

// all-clear conditions: a video is selected and nothing suggests we should pause.
private func clearConditions() -> PlaybackConditions {
    PlaybackConditions(
        hasVideo: true,
        isOccluded: false,
        isFullscreenAppFrontmost: false,
        isOnBattery: false
    )
}

func runPlaybackPolicyTests(_ t: TestRunner) {
    // plays when a video is selected and nothing blocks playback.
    t.expectEqual(PlaybackPolicy(pauseOnBattery: true).decide(clearConditions()), .play)

    // pauses when no video is selected.
    var noVideo = clearConditions()
    noVideo.hasVideo = false
    t.expectEqual(PlaybackPolicy(pauseOnBattery: true).decide(noVideo), .pause)

    // occlusion no longer pauses: macOS does not reliably signal when a desktop-level window
    // becomes visible again after a Space switch, so pausing on occlusion strands the video
    // paused (and a long-off-screen paused layer renders black). we keep playing instead.
    var occluded = clearConditions()
    occluded.isOccluded = true
    t.expectEqual(PlaybackPolicy(pauseOnBattery: true).decide(occluded), .play)

    // pauses when a fullscreen app is frontmost.
    var fullscreen = clearConditions()
    fullscreen.isFullscreenAppFrontmost = true
    t.expectEqual(PlaybackPolicy(pauseOnBattery: true).decide(fullscreen), .pause)

    // pauses on battery when pause-on-battery is enabled.
    var onBattery = clearConditions()
    onBattery.isOnBattery = true
    t.expectEqual(PlaybackPolicy(pauseOnBattery: true).decide(onBattery), .pause)

    // keeps playing on battery when pause-on-battery is disabled.
    var onBatteryAllowed = clearConditions()
    onBatteryAllowed.isOnBattery = true
    t.expectEqual(PlaybackPolicy(pauseOnBattery: false).decide(onBatteryAllowed), .play)
}
