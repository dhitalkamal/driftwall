import AVFoundation

// wraps an AVQueuePlayer + AVPlayerLooper for gapless looping. the looper must be retained
// or looping silently stops, so it is held in a strong property. exposes the underlying
// player so the window layers can bind to it (one player, many AVPlayerLayers).
@MainActor
final class VideoLooperPlayer {
    let player = AVQueuePlayer()
    private var looper: AVPlayerLooper?

    init() {
        player.isMuted = true
        player.volume = 0
        // the looper drives item cycling; do not let the queue player advance on its own.
        player.actionAtItemEnd = .none
    }

    func load(url: URL) {
        let item = AVPlayerItem(url: url)
        // recreate the looper for the new item; dropping the old one stops its treadmill.
        looper = AVPlayerLooper(player: player, templateItem: item)
    }

    func play() {
        player.play()
    }

    func pause() {
        player.pause()
    }

    func teardown() {
        player.pause()
        looper = nil
        player.removeAllItems()
    }
}
