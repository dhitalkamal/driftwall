// what to do when a fullscreen app is frontmost but the wallpaper is still visible on another
// display. when a fullscreen app covers every display the wallpaper pauses in either mode,
// since nothing is visible.
public enum FullscreenBehavior: String, Codable, Equatable, Sendable, CaseIterable {
    // keep the visible displays animating, silence the audio.
    case muteAudio
    // pause playback on every display.
    case pauseAll
}
