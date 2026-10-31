import Foundation

// decides which video plays on a given display. precedence: an enabled playlist that can
// rotate (two or more videos) beats a per-display override, which beats the single video
// applied to every display. a one-video playlist cannot rotate, so it only fills in when
// nothing else is chosen.
public enum WallpaperResolver {
    public static func video(
        for displayId: String,
        config: WallpaperConfig,
        playlistOrder: [Int],
        playlistAdvance: Int
    ) -> URL? {
        let playlist = config.playlistEnabled ? config.playlist : nil
        if let playlist, playlist.videos.count >= 2 {
            return RotationState.currentVideo(
                playlist: playlist, order: playlistOrder, advanceCount: playlistAdvance
            )
        }
        if let perDisplay = config.perDisplayVideos[displayId] {
            return perDisplay
        }
        return config.selectedVideo ?? playlist?.videos.first
    }
}
