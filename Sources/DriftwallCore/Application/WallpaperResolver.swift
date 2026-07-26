import Foundation

// decides which video plays on a given display. precedence: an enabled playlist beats a
// per-display override, which beats the single video applied to every display.
public enum WallpaperResolver {
    public static func video(
        for displayId: String,
        config: WallpaperConfig,
        playlistOrder: [Int],
        playlistAdvance: Int
    ) -> URL? {
        if config.playlistEnabled,
           let playlist = config.playlist,
           !playlist.isEmpty {
            return RotationState.currentVideo(
                playlist: playlist, order: playlistOrder, advanceCount: playlistAdvance
            )
        }
        if let perDisplay = config.perDisplayVideos[displayId] {
            return perDisplay
        }
        return config.selectedVideo
    }
}
