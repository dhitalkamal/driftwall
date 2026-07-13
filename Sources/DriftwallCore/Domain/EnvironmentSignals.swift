// live environment signals sampled from the system that feed the playback decision.
// separate from WallpaperConfig, which is user settings that persist.
public struct EnvironmentSignals: Equatable, Sendable {
    public var isOccluded: Bool
    public var isFullscreenAppFrontmost: Bool
    public var isOnBattery: Bool

    public init(
        isOccluded: Bool,
        isFullscreenAppFrontmost: Bool,
        isOnBattery: Bool
    ) {
        self.isOccluded = isOccluded
        self.isFullscreenAppFrontmost = isFullscreenAppFrontmost
        self.isOnBattery = isOnBattery
    }
}
