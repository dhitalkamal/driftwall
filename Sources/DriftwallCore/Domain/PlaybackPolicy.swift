// playback policy: pure decision logic for when the wallpaper should play.

// the environmental inputs that decide whether the wallpaper video should be playing.
public struct PlaybackConditions: Equatable, Sendable {
    public var hasVideo: Bool
    public var isOccluded: Bool
    public var isFullscreenAppFrontmost: Bool
    public var isOnBattery: Bool
    public var isDisplayAsleep: Bool
    public var isFullscreenOnEveryDisplay: Bool

    public init(
        hasVideo: Bool,
        isOccluded: Bool,
        isFullscreenAppFrontmost: Bool,
        isOnBattery: Bool,
        isDisplayAsleep: Bool = false,
        isFullscreenOnEveryDisplay: Bool = false
    ) {
        self.hasVideo = hasVideo
        self.isOccluded = isOccluded
        self.isFullscreenAppFrontmost = isFullscreenAppFrontmost
        self.isOnBattery = isOnBattery
        self.isDisplayAsleep = isDisplayAsleep
        self.isFullscreenOnEveryDisplay = isFullscreenOnEveryDisplay
    }
}

public enum PlaybackDecision: Equatable, Sendable {
    case play
    // keep playing for the displays that can still see it, but with audio silenced.
    case playMuted
    case pause
}

// decides whether the wallpaper should play given the current conditions. the tunables are
// whether playback pauses on battery and what a fullscreen app does, both user controlled.
public struct PlaybackPolicy: Sendable {
    public let pauseOnBattery: Bool
    public let fullscreenBehavior: FullscreenBehavior

    public init(pauseOnBattery: Bool = true, fullscreenBehavior: FullscreenBehavior = .muteAudio) {
        self.pauseOnBattery = pauseOnBattery
        self.fullscreenBehavior = fullscreenBehavior
    }

    public func decide(_ conditions: PlaybackConditions) -> PlaybackDecision {
        guard conditions.hasVideo else { return .pause }
        // display asleep or screen locked: nothing is viewable, so always pause.
        if conditions.isDisplayAsleep { return .pause }
        // pause when the wallpaper is genuinely hidden, to avoid decoding video no one can see.
        // the app debounces occlusion before setting isOccluded and forces it back to visible on
        // a Space change, so a brief occlusion during a switch never pauses (which would strand a
        // black/paused frame on return); only sustained occlusion pauses.
        if conditions.isOccluded { return .pause }
        // fullscreen on every display hides the wallpaper everywhere (the single-display case).
        if conditions.isFullscreenOnEveryDisplay { return .pause }
        if conditions.isOnBattery && pauseOnBattery { return .pause }
        // fullscreen on some displays only: the rest still show the wallpaper, so the user picks
        // between silencing it and pausing it everywhere.
        if conditions.isFullscreenAppFrontmost {
            return fullscreenBehavior == .pauseAll ? .pause : .playMuted
        }
        return .play
    }
}
