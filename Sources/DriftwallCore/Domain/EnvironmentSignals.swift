// live environment signals sampled from the system that feed the playback decision.
// separate from WallpaperConfig, which is user settings that persist.
public struct EnvironmentSignals: Equatable, Sendable {
    public var isOccluded: Bool
    public var isFullscreenAppFrontmost: Bool
    public var isOnBattery: Bool
    // the display is asleep or the screen is locked: the wallpaper is physically unviewable, so
    // playback should hard-pause immediately (no debounce) to stop decoding video no one sees.
    public var isDisplayAsleep: Bool

    public init(
        isOccluded: Bool,
        isFullscreenAppFrontmost: Bool,
        isOnBattery: Bool,
        isDisplayAsleep: Bool = false
    ) {
        self.isOccluded = isOccluded
        self.isFullscreenAppFrontmost = isFullscreenAppFrontmost
        self.isOnBattery = isOnBattery
        self.isDisplayAsleep = isDisplayAsleep
    }
}
