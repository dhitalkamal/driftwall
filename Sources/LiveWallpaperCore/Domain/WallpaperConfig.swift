import Foundation

// persisted user settings for the wallpaper. plain value type so it round-trips through
// json and stays free of any AppKit/AVFoundation dependency.
public struct WallpaperConfig: Codable, Equatable, Sendable {
    public var selectedVideo: URL?
    public var pauseOnBattery: Bool

    public init(
        selectedVideo: URL? = nil,
        pauseOnBattery: Bool = true
    ) {
        self.selectedVideo = selectedVideo
        self.pauseOnBattery = pauseOnBattery
    }

    public var hasVideo: Bool {
        selectedVideo != nil
    }
}
