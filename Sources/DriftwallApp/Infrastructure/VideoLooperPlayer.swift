import AVFoundation

// wraps an AVQueuePlayer + AVPlayerLooper for gapless looping. the looper must be retained
// or looping silently stops, so it is held in a strong property. exposes the underlying
// player so the window layers can bind to it (one player, many AVPlayerLayers). observes the
// item status so a file that fails to load is reported instead of failing silently, and runs
// a watchdog that rebuilds the pipeline if playback stalls (a video layer that has been off a
// non-active Space for a long time can lose its GPU surface and go black).
@MainActor
final class VideoLooperPlayer {
    let player = AVQueuePlayer()
    private var looper: AVPlayerLooper?
    private var statusObservation: NSKeyValueObservation?
    private var currentURL: URL?
    private var isPlaying = false

    private var watchdog: Timer?
    private var lastObservedSeconds: Double = 0
    private var stalledSamples = 0

    // invoked on the main thread when the loaded item fails to become ready.
    var onLoadFailure: (@MainActor (String) -> Void)?

    init() {
        player.isMuted = true
        player.volume = 0
        // the looper drives item cycling; do not let the queue player advance on its own.
        player.actionAtItemEnd = .none
        startWatchdog()
    }

    func load(url: URL) {
        currentURL = url
        buildPipeline(for: url)
    }

    private func buildPipeline(for url: URL) {
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
        if isPlaying {
            player.playImmediately(atRate: 1.0)
        }
    }

    func setVolume(_ volume: Double) {
        let clamped = min(1, max(0, volume))
        player.volume = Float(clamped)
        player.isMuted = clamped <= 0
    }

    func play() {
        isPlaying = true
        // playImmediately pushes a frame as soon as one is available, unlike play().
        player.playImmediately(atRate: 1.0)
    }

    func pause() {
        isPlaying = false
        player.pause()
    }

    // force the layer to present a fresh frame without restarting the video: a zero-tolerance
    // seek to the current time repaints a surface that was reclaimed while off-screen.
    func forceCurrentFrame() {
        guard currentURL != nil else { return }
        let now = player.currentTime()
        player.seek(to: now, toleranceBefore: .zero, toleranceAfter: .zero)
        if isPlaying {
            player.playImmediately(atRate: 1.0)
        }
    }

    func teardown() {
        isPlaying = false
        player.pause()
        statusObservation = nil
        looper = nil
        player.removeAllItems()
        currentURL = nil
    }

    // sample playback every few seconds; if it should be playing but time has not advanced for
    // two samples, rebuild the pipeline to recover from a stalled/black state.
    private func startWatchdog() {
        let timer = Timer(timeInterval: 5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.checkProgress() }
        }
        RunLoop.main.add(timer, forMode: .common)
        watchdog = timer
    }

    private func checkProgress() {
        guard isPlaying, let url = currentURL else {
            stalledSamples = 0
            return
        }
        let seconds = player.currentTime().seconds
        if seconds.isFinite, seconds > lastObservedSeconds + 0.01 {
            stalledSamples = 0
        } else {
            stalledSamples += 1
            if stalledSamples >= 2 {
                stalledSamples = 0
                buildPipeline(for: url)  // hard recovery: fresh decode pipeline and surface.
            }
        }
        lastObservedSeconds = player.currentTime().seconds
    }
}
