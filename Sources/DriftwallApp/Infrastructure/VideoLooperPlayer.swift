import AVFoundation
import AppKit

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
    private var currentItemObservation: NSKeyValueObservation?
    private var currentURL: URL?
    private var isPlaying = false
    private var desiredRate: Float = 1.0

    private var watchdog: Timer?
    private var stalledSamples = 0

    // invoked on the main thread when the loaded item fails to become ready.
    var onLoadFailure: (@MainActor (String) -> Void)?

    init() {
        player.isMuted = true
        player.volume = 0
        // the looper drives item cycling; do not let the queue player advance on its own.
        player.actionAtItemEnd = .none
        // a muted, local-file wallpaper never AirPlays and never needs network stall heuristics;
        // disabling both drops AirPlay route monitoring and tightens local startup.
        player.allowsExternalPlayback = false
        player.automaticallyWaitsToMinimizeStalling = false
        // AVPlayerLooper resets the rate to 1.0 each time it advances to the next looped item,
        // so re-apply the desired speed whenever the current item changes.
        currentItemObservation = player.observe(\.currentItem) { [weak self] player, _ in
            MainActor.assumeIsolated {
                guard let self, self.isPlaying, player.currentItem != nil else { return }
                player.rate = self.desiredRate
            }
        }
    }

    func load(url: URL) {
        currentURL = url
        buildPipeline(for: url)
    }

    private func buildPipeline(for url: URL) {
        let item = AVPlayerItem(url: url)
        // decode no larger than the displays can show. a 4K clip on a 1512x982@2x screen only
        // needs ~3024x1964 pixels; capping here cuts decode CPU/GPU and memory with no visible
        // change, which matters a lot for a wallpaper that plays continuously.
        item.preferredMaximumResolution = maxDisplayPixelSize
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
            player.playImmediately(atRate: desiredRate)
        }
    }

    func setVolume(_ volume: Double) {
        let clamped = min(1, max(0, volume))
        player.volume = Float(clamped)
        player.isMuted = clamped <= 0
    }

    func setSpeed(_ rate: Double) {
        desiredRate = Float(min(2.0, max(0.25, rate)))
        if isPlaying {
            player.playImmediately(atRate: desiredRate)
        }
    }

    func play() {
        isPlaying = true
        // playImmediately pushes a frame as soon as one is available, unlike play().
        player.playImmediately(atRate: desiredRate)
        // the stall watchdog only needs to run while we expect playback; no wakeups while paused.
        startWatchdog()
    }

    func pause() {
        isPlaying = false
        player.pause()
        stopWatchdog()
    }

    // present a fresh frame on a layer whose surface was reclaimed while off a non-active Space.
    // a live (playing) player feeds a freshly rebuilt layer on its own within a frame, so just
    // (re)assert playback. only a paused player needs a nudge, and it uses a default-tolerance
    // seek: a zero-tolerance seek re-decodes precisely from the keyframe and can stall ~1-2s on
    // 4K footage — that stall was the visible "stuck for a second" on Space return.
    func forceCurrentFrame() {
        guard currentURL != nil else { return }
        if isPlaying {
            player.playImmediately(atRate: desiredRate)
        } else {
            player.seek(to: player.currentTime())
        }
    }

    func teardown() {
        isPlaying = false
        player.pause()
        stopWatchdog()
        statusObservation = nil
        looper = nil
        player.removeAllItems()
        currentURL = nil
    }

    // the largest pixel size across all displays; decoding above this wastes work for a
    // wallpaper. floors at 1080p so an unusual display report never starves quality.
    private var maxDisplayPixelSize: CGSize {
        var size = CGSize(width: 1920, height: 1080)
        for screen in NSScreen.screens {
            let scale = screen.backingScaleFactor
            size.width = max(size.width, screen.frame.width * scale)
            size.height = max(size.height, screen.frame.height * scale)
        }
        return size
    }

    // sample playback every few seconds; if we expect it to be playing but the player is not
    // actually in the playing state for two samples, rebuild the pipeline to recover from a
    // stalled state. uses timeControlStatus (not currentTime, which cycles on loop and would
    // false-trigger) so looping never looks like a stall. only runs while playing, so a paused
    // wallpaper causes no periodic run-loop wakeups.
    private func startWatchdog() {
        watchdog?.invalidate()
        stalledSamples = 0
        let timer = Timer(timeInterval: 5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.checkProgress() }
        }
        RunLoop.main.add(timer, forMode: .common)
        watchdog = timer
    }

    private func stopWatchdog() {
        watchdog?.invalidate()
        watchdog = nil
        stalledSamples = 0
    }

    private func checkProgress() {
        guard isPlaying, let url = currentURL else {
            stalledSamples = 0
            return
        }
        if player.timeControlStatus == .playing {
            stalledSamples = 0
        } else {
            stalledSamples += 1
            if stalledSamples >= 2 {
                stalledSamples = 0
                buildPipeline(for: url)  // hard recovery: fresh decode pipeline and surface.
            }
        }
    }
}
