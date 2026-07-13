import Foundation

// decides which video plays on a given display, honoring the license tier. precedence:
// an enabled playlist (pro) beats a per-display override (pro), which beats the single
// video (free). free tier always falls through to the single video.
public enum WallpaperResolver {
    public static func video(
        for displayId: String,
        config: WallpaperConfig,
        tier: LicenseTier,
        playlistOrder: [Int],
        playlistAdvance: Int
    ) -> URL? {
        if config.playlistEnabled,
           let playlist = config.playlist,
           !playlist.isEmpty,
           FeatureGate.isAllowed(.playlists, tier: tier) {
            return RotationState.currentVideo(
                playlist: playlist, order: playlistOrder, advanceCount: playlistAdvance
            )
        }
        if FeatureGate.isAllowed(.perDisplayVideo, tier: tier),
           let perDisplay = config.perDisplayVideos[displayId] {
            return perDisplay
        }
        return config.selectedVideo
    }
}
