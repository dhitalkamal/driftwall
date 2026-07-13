// playback policy: pure decision logic for when the wallpaper should play.

// the environmental inputs that decide whether the wallpaper video should be playing.
public struct PlaybackConditions: Equatable, Sendable {
    public var hasVideo: Bool
    public var isOccluded: Bool
    public var isFullscreenAppFrontmost: Bool
    public var isOnBattery: Bool

    public init(
        hasVideo: Bool,
        isOccluded: Bool,
        isFullscreenAppFrontmost: Bool,
        isOnBattery: Bool
    ) {
        self.hasVideo = hasVideo
        self.isOccluded = isOccluded
        self.isFullscreenAppFrontmost = isFullscreenAppFrontmost
        self.isOnBattery = isOnBattery
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
        // note: occlusion is deliberately NOT a pause trigger. macOS does not reliably report
        // when a desktop-level window becomes visible again after a Space switch, so pausing on
        // occlusion strands the video paused and a long-off-screen paused layer renders black.
        // keeping it playing guarantees a fresh frame is ready on return.
        if conditions.isFullscreenAppFrontmost { return .pause }
        if conditions.isOnBattery && pauseOnBattery { return .pause }
        return .play
    }
}
