// the effective playback state the app surfaces to the user (e.g. the menu-bar icon). distinct
// from PlaybackDecision, which is only the play/pause choice made while a video is showing.
public enum PlaybackState: Equatable, Sendable {
    case idle // no video showing
    case playing
    case paused
}
