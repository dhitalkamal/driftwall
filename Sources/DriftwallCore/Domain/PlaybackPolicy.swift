// playback policy: pure decision logic for when the wallpaper should play.

// the environmental inputs that decide whether the wallpaper video should be playing.
public struct PlaybackConditions: Equatable, Sendable {
    public var hasVideo: Bool
    public var isOccluded: Bool
    public var isFullscreenAppFrontmost: Bool
    public var isOnBattery: Bool
    public var isDisplayAsleep: Bool

    public init(
        hasVideo: Bool,
        isOccluded: Bool,
        isFullscreenAppFrontmost: Bool,
        isOnBattery: Bool,
        isDisplayAsleep: Bool = false
    ) {
        self.hasVideo = hasVideo
        self.isOccluded = isOccluded
        self.isFullscreenAppFrontmost = isFullscreenAppFrontmost
        self.isOnBattery = isOnBattery
        self.isDisplayAsleep = isDisplayAsleep
    }
}

public enum PlaybackDecision: Equatable, Sendable {
    case play
    case pause
}

// decides whether the wallpaper should play given the current conditions. the only tunable
// is whether playback pauses while on battery, which the user controls.
public struct PlaybackPolicy: Sendable {
    public let pauseOnBattery: Bool

    public init(pauseOnBattery: Bool = true) {
        self.pauseOnBattery = pauseOnBattery
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
        if conditions.isFullscreenAppFrontmost { return .pause }
        if conditions.isOnBattery && pauseOnBattery { return .pause }
        return .play
    }
}
