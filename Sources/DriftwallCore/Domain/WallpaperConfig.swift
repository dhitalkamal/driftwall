import Foundation

// persisted user settings for the wallpaper. plain value type so it round-trips through json
// and stays free of any AppKit/AVFoundation dependency. decoding tolerates older files that
// predate newer fields by falling back to defaults, so upgrades never wipe a user's setup.
public struct WallpaperConfig: Codable, Equatable, Sendable {
    // a single video applied to every display.
    public var selectedVideo: URL?
    // a distinct video per display, keyed by a stable display id.
    public var perDisplayVideos: [String: URL]
    public var fitMode: FitMode
    // rotate through a set of videos when enabled.
    public var playlist: Playlist?
    public var playlistEnabled: Bool
    public var playbackSettings: PlaybackSettings
    public var pauseOnBattery: Bool
    // when true, take over the macOS desktop picture while active so the system animates
    // nothing behind our video, restoring it on quit.
    public var replaceSystemWallpaper: Bool
    // when true, the wallpaper window joins every Space; when false it stays on the Space it
    // was created on.
    public var showOnAllSpaces: Bool

    public init(
        selectedVideo: URL? = nil,
        perDisplayVideos: [String: URL] = [:],
        fitMode: FitMode = .fill,
        playlist: Playlist? = nil,
        playlistEnabled: Bool = false,
        playbackSettings: PlaybackSettings = PlaybackSettings(),
        pauseOnBattery: Bool = true,
        replaceSystemWallpaper: Bool = true,
        showOnAllSpaces: Bool = true
    ) {
        self.selectedVideo = selectedVideo
        self.perDisplayVideos = perDisplayVideos
        self.fitMode = fitMode
        self.playlist = playlist
        self.playlistEnabled = playlistEnabled
        self.playbackSettings = playbackSettings
        self.pauseOnBattery = pauseOnBattery
        self.replaceSystemWallpaper = replaceSystemWallpaper
        self.showOnAllSpaces = showOnAllSpaces
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
            replaceSystemWallpaper: try c.decodeIfPresent(Bool.self, forKey: .replaceSystemWallpaper) ?? true,
            showOnAllSpaces: try c.decodeIfPresent(Bool.self, forKey: .showOnAllSpaces) ?? true
        )
    }

    // true when there is any video to show: a single selection, a per-display override, or an
    // enabled non-empty playlist.
    public var hasVideo: Bool {
        selectedVideo != nil
            || !perDisplayVideos.isEmpty
            || (playlistEnabled && !(playlist?.videos.isEmpty ?? true))
    }
}
