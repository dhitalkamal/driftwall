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

    // pauses when hidden. the app debounces occlusion (and forces visible on a Space change)
    // before setting isOccluded, so this only fires for sustained occlusion, not a brief switch.
    var occluded = clearConditions()
    occluded.isOccluded = true
    t.expectEqual(PlaybackPolicy(pauseOnBattery: true).decide(occluded), .pause)

    // a fullscreen app covering every display hides the wallpaper everywhere: pause in both
    // modes (this is the single-display case).
    var everywhere = clearConditions()
    everywhere.isFullscreenAppFrontmost = true
    everywhere.isFullscreenOnEveryDisplay = true
    t.expectEqual(PlaybackPolicy(fullscreenBehavior: .muteAudio).decide(everywhere), .pause)
    t.expectEqual(PlaybackPolicy(fullscreenBehavior: .pauseAll).decide(everywhere), .pause)

    // every display covered pauses even if the frontmost app is not the fullscreen one.
    var coveredNotFrontmost = clearConditions()
    coveredNotFrontmost.isFullscreenOnEveryDisplay = true
    t.expectEqual(PlaybackPolicy().decide(coveredNotFrontmost), .pause)

    // fullscreen app frontmost on one display while another still shows the wallpaper: mute
    // only by default, keep the visible display animating.
    var partial = clearConditions()
    partial.isFullscreenAppFrontmost = true
    t.expectEqual(PlaybackPolicy().decide(partial), .playMuted)
    t.expectEqual(PlaybackPolicy(fullscreenBehavior: .muteAudio).decide(partial), .playMuted)

    // same situation with pause-everything chosen: pause.
    t.expectEqual(PlaybackPolicy(fullscreenBehavior: .pauseAll).decide(partial), .pause)

    // a pause reason (battery) wins over muted playback.
    var partialOnBattery = partial
    partialOnBattery.isOnBattery = true
    t.expectEqual(PlaybackPolicy(pauseOnBattery: true).decide(partialOnBattery), .pause)

    // pauses on battery when pause-on-battery is enabled.
    var onBattery = clearConditions()
    onBattery.isOnBattery = true
    t.expectEqual(PlaybackPolicy(pauseOnBattery: true).decide(onBattery), .pause)

    // keeps playing on battery when pause-on-battery is disabled.
    var onBatteryAllowed = clearConditions()
    onBatteryAllowed.isOnBattery = true
    t.expectEqual(PlaybackPolicy(pauseOnBattery: false).decide(onBatteryAllowed), .play)
}
