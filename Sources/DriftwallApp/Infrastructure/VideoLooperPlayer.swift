import AVFoundation

// wraps an AVQueuePlayer + AVPlayerLooper for gapless looping. the looper must be retained
// or looping silently stops, so it is held in a strong property. exposes the underlying
// player so the window layers can bind to it (one player, many AVPlayerLayers). observes the
// item status so a file that fails to load is reported instead of failing silently.
@MainActor
final class VideoLooperPlayer {
    let player = AVQueuePlayer()
    private var looper: AVPlayerLooper?
    private var statusObservation: NSKeyValueObservation?

    // invoked on the main thread when the loaded item fails to become ready.
    var onLoadFailure: (@MainActor (String) -> Void)?

    init() {
        player.isMuted = true
        player.volume = 0
        // the looper drives item cycling; do not let the queue player advance on its own.
        player.actionAtItemEnd = .none
    }

    func load(url: URL) {
        let item = AVPlayerItem(url: url)
        // surface a load failure (unsupported codec, corrupt, unreadable) instead of leaving
        // a silent transparent window.
        statusObservation = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            guard item.status == .failed else { return }
            let message = item.error?.localizedDescription ?? "The video could not be played."
            MainActor.assumeIsolated { self?.onLoadFailure?(message) }
        }
        // recreate the looper for the new item; dropping the old one stops its treadmill.
        looper = AVPlayerLooper(player: player, templateItem: item)
    }

    func setVolume(_ volume: Double) {
        let clamped = min(1, max(0, volume))
        player.volume = Float(clamped)
        player.isMuted = clamped <= 0
    }

    func play() {
        player.play()
    }

    func pause() {
        player.pause()
    }

    func teardown() {
        player.pause()
        statusObservation = nil
        looper = nil
        player.removeAllItems()
    }
}
