import Foundation

// persisted user settings for the wallpaper. plain value type so it round-trips through
// json and stays free of any AppKit/AVFoundation dependency.
public struct WallpaperConfig: Codable, Equatable, Sendable {
    public var selectedVideo: URL?
    public var pauseOnBattery: Bool
    public var launchAtLogin: Bool

    public init(
        selectedVideo: URL? = nil,
        pauseOnBattery: Bool = true,
        launchAtLogin: Bool = false
    ) {
        self.selectedVideo = selectedVideo
        self.pauseOnBattery = pauseOnBattery
        self.launchAtLogin = launchAtLogin
    }

    public var hasVideo: Bool {
        selectedVideo != nil
    }
}
