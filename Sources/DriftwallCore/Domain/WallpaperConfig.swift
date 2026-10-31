import Foundation

// persisted user settings for the wallpaper. plain value type so it round-trips through json
// and stays free of any AppKit/AVFoundation dependency. decoding tolerates older files that
// predate newer fields, or hold values this build cannot read, by falling back to defaults
// per field, so upgrades and downgrades never wipe a user's setup.
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
    // what a fullscreen app on one display does to the wallpaper on the others.
    public var fullscreenBehavior: FullscreenBehavior

    public init(
        selectedVideo: URL? = nil,
        perDisplayVideos: [String: URL] = [:],
        fitMode: FitMode = .fill,
        playlist: Playlist? = nil,
        playlistEnabled: Bool = false,
        playbackSettings: PlaybackSettings = PlaybackSettings(),
        pauseOnBattery: Bool = true,
        replaceSystemWallpaper: Bool = true,
        showOnAllSpaces: Bool = true,
        fullscreenBehavior: FullscreenBehavior = .muteAudio
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
        self.fullscreenBehavior = fullscreenBehavior
    }

    // each field decodes on its own: a missing or undecodable value uses that field's default
    // and the other fields are kept. only a non-object payload still throws.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            selectedVideo: c.decodeLenient(URL.self, forKey: .selectedVideo),
            perDisplayVideos: c.decodeLenient([String: URL].self, forKey: .perDisplayVideos) ?? [:],
            fitMode: c.decodeLenient(FitMode.self, forKey: .fitMode) ?? .fill,
            playlist: c.decodeLenient(Playlist.self, forKey: .playlist),
            playlistEnabled: c.decodeLenient(Bool.self, forKey: .playlistEnabled) ?? false,
            playbackSettings: c.decodeLenient(PlaybackSettings.self, forKey: .playbackSettings) ?? PlaybackSettings(),
            pauseOnBattery: c.decodeLenient(Bool.self, forKey: .pauseOnBattery) ?? true,
            replaceSystemWallpaper: c.decodeLenient(Bool.self, forKey: .replaceSystemWallpaper) ?? true,
            showOnAllSpaces: c.decodeLenient(Bool.self, forKey: .showOnAllSpaces) ?? true,
            fullscreenBehavior: c.decodeLenient(FullscreenBehavior.self, forKey: .fullscreenBehavior) ?? .muteAudio
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
