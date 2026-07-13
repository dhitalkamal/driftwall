import Foundation

// persisted user settings for the wallpaper. plain value type so it round-trips through json
// and stays free of any AppKit/AVFoundation dependency. decoding tolerates older files that
// predate newer fields by falling back to defaults, so upgrades never wipe a user's setup.
public struct WallpaperConfig: Codable, Equatable, Sendable {
    // free: a single video applied to every display.
    public var selectedVideo: URL?
    // pro: a distinct video per display, keyed by a stable display id.
    public var perDisplayVideos: [String: URL]
    public var fitMode: FitMode
    // pro: rotate through a set of videos when enabled.
    public var playlist: Playlist?
    public var playlistEnabled: Bool
    public var playbackSettings: PlaybackSettings
    public var pauseOnBattery: Bool
    // the raw signed license token, verified in the app layer to derive the tier.
    public var licenseToken: String?

    public init(
        selectedVideo: URL? = nil,
        perDisplayVideos: [String: URL] = [:],
        fitMode: FitMode = .fill,
        playlist: Playlist? = nil,
        playlistEnabled: Bool = false,
        playbackSettings: PlaybackSettings = PlaybackSettings(),
        pauseOnBattery: Bool = true,
        licenseToken: String? = nil
    ) {
        self.selectedVideo = selectedVideo
        self.perDisplayVideos = perDisplayVideos
        self.fitMode = fitMode
        self.playlist = playlist
        self.playlistEnabled = playlistEnabled
        self.playbackSettings = playbackSettings
        self.pauseOnBattery = pauseOnBattery
        self.licenseToken = licenseToken
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            selectedVideo: try c.decodeIfPresent(URL.self, forKey: .selectedVideo),
            perDisplayVideos: try c.decodeIfPresent([String: URL].self, forKey: .perDisplayVideos) ?? [:],
            fitMode: try c.decodeIfPresent(FitMode.self, forKey: .fitMode) ?? .fill,
            playlist: try c.decodeIfPresent(Playlist.self, forKey: .playlist),
            playlistEnabled: try c.decodeIfPresent(Bool.self, forKey: .playlistEnabled) ?? false,
            playbackSettings: try c.decodeIfPresent(PlaybackSettings.self, forKey: .playbackSettings) ?? PlaybackSettings(),
            pauseOnBattery: try c.decodeIfPresent(Bool.self, forKey: .pauseOnBattery) ?? true,
            licenseToken: try c.decodeIfPresent(String.self, forKey: .licenseToken)
        )
    }

    // true when there is any video to show, from the single selection or a per-display override.
    public var hasVideo: Bool {
        selectedVideo != nil || !perDisplayVideos.isEmpty
    }
}
