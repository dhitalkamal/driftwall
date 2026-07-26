import Foundation

// orchestrates the wallpaper: owns the current config and the latest environment signals, and
// drives the renderer through the playback policy. main-actor
// isolated: it runs on the main thread and drives main-actor renderer/store adapters.
@MainActor
public final class WallpaperController {
    private let store: ConfigStoring
    private let renderer: WallpaperRendering
    private let systemWallpaper: SystemWallpaperControlling

    public private(set) var config: WallpaperConfig
    private var environment: EnvironmentSignals
    private var isShowing = false
    private var didTakeOverSystemWallpaper = false

    // playlist rotation state. order is the play sequence (shuffled or natural); advance counts
    // how many times we have rotated. resolved via WallpaperResolver.
    private var playlistOrder: [Int] = []
    private var playlistAdvance = 0

    // fired when the rotation schedule may have changed (playlist edited or enabled) so the app
    // can (re)schedule its rotation timer.
    public var onRotationScheduleChanged: (@MainActor () -> Void)?

    // fired when the effective playback state changes so the app can reflect it (menu-bar icon).
    // primes a newly attached observer with the current state, since playback may already be
    // decided (e.g. license restore runs before the app wires this up) and the change-dedup
    // below would otherwise swallow the first emission.
    public var onPlaybackStateChanged: (@MainActor (PlaybackState) -> Void)? {
        didSet {
            if let lastPlaybackState { onPlaybackStateChanged?(lastPlaybackState) }
        }
    }
    private var lastPlaybackState: PlaybackState?

    public init(
        store: ConfigStoring,
        renderer: WallpaperRendering,
        systemWallpaper: SystemWallpaperControlling = NoopSystemWallpaper()
    ) {
        self.store = store
        self.renderer = renderer
        self.systemWallpaper = systemWallpaper
        self.config = store.load()
        self.environment = EnvironmentSignals(
            isOccluded: false,
            isFullscreenAppFrontmost: false,
            isOnBattery: false
        )
        regeneratePlaylistOrder()
    }

    // called once at launch: adopt the initial environment, restore the saved video, and
    // apply the playback decision.
    public func start(environment: EnvironmentSignals) {
        self.environment = environment
        config = store.load()
        regeneratePlaylistOrder()
        refreshSurface()
        applyPlayback()
        onRotationScheduleChanged?()
    }

    // user picked a new single video: persist it, show it, and re-evaluate playback.
    public func selectVideo(_ url: URL) {
        config.selectedVideo = url
        store.save(config)
        refreshSurface()
        applyPlayback()
    }

    // clear the wallpaper without quitting: forget the video and tear the surface down.
    public func clearVideo() {
        config.selectedVideo = nil
        config.perDisplayVideos = [:]
        config.playlistEnabled = false
        store.save(config)
        refreshSurface()
        onRotationScheduleChanged?()
    }

    public func setFitMode(_ mode: FitMode) {
        config.fitMode = mode
        store.save(config)
        renderer.setFitMode(mode)
        systemWallpaper.setFitMode(mode)
    }

    public func setPlaybackSettings(_ settings: PlaybackSettings) {
        config.playbackSettings = settings
        store.save(config)
        renderer.setVolume(settings.volume)
        renderer.setDim(settings.dim)
        renderer.setSpeed(config.playbackSettings.speed)
    }

    // replace the playlist (videos, shuffle, interval). enabling is separate.
    public func setPlaylist(_ playlist: Playlist?) {
        config.playlist = playlist
        store.save(config)
        regeneratePlaylistOrder()
        refreshSurface()
        applyPlayback()
        onRotationScheduleChanged?()
    }

    // turn playlist rotation on/off.
    public func setPlaylistEnabled(_ enabled: Bool) {
        config.playlistEnabled = enabled
        store.save(config)
        regeneratePlaylistOrder()
        refreshSurface()
        applyPlayback()
        onRotationScheduleChanged?()
    }

    // advance to the next playlist item (called by the app's rotation timer).
    public func advancePlaylist() {
        guard rotationIntervalSeconds != nil else { return }
        playlistAdvance += 1
        refreshSurface()
        applyPlayback()
    }

    // the rotation interval in seconds when rotation is active (enabled, 2+ videos), otherwise
    // nil (no timer should run).
    public var rotationIntervalSeconds: Int? {
        guard config.playlistEnabled,
              let playlist = config.playlist,
              playlist.videos.count >= 2 else {
            return nil
        }
        return playlist.intervalSeconds
    }

    // user toggled whether playback pauses on battery.
    public func setPauseOnBattery(_ enabled: Bool) {
        config.pauseOnBattery = enabled
        store.save(config)
        applyPlayback()
    }

    // user toggled whether we take over the macOS desktop picture while active.
    public func setReplaceSystemWallpaper(_ enabled: Bool) {
        config.replaceSystemWallpaper = enabled
        store.save(config)
        syncSystemWallpaper()
    }

    // user toggled whether the wallpaper shows on every Space.
    public func setShowOnAllSpaces(_ enabled: Bool) {
        config.showOnAllSpaces = enabled
        store.save(config)
        renderer.setShowOnAllSpaces(enabled)
    }

    // restore the macOS desktop picture. call on quit so the user's wallpaper comes back.
    public func restoreSystemWallpaper() {
        if didTakeOverSystemWallpaper {
            systemWallpaper.restore()
            didTakeOverSystemWallpaper = false
        }
    }

    // an environment signal changed (occlusion, fullscreen app, battery).
    public func updateEnvironment(_ environment: EnvironmentSignals) {
        self.environment = environment
        applyPlayback()
    }

    // the display arrangement changed (monitor plugged/unplugged). re-run takeover so any
    // newly attached display is also covered; takeOver is additive/idempotent per display.
    public func handleScreensChanged() {
        if isShowing && config.replaceSystemWallpaper {
            systemWallpaper.takeOver()
            didTakeOverSystemWallpaper = true
        }
    }

    // the active Space changed. macOS does not reliably deliver a window-occlusion event when
    // returning to a Space, so re-run the playback decision here and force the renderer to
    // repaint a fresh frame (a paused/long-off-screen video layer otherwise shows black).
    public func handleSpaceChanged() {
        guard isShowing else { return }
        applyPlayback()
        renderer.refresh()
    }

    private func regeneratePlaylistOrder() {
        playlistAdvance = 0
        let count = config.playlist?.videos.count ?? 0
        let indices = Array(0..<count)
        playlistOrder = (config.playlist?.shuffle ?? false) ? indices.shuffled() : indices
    }

    // show the resolved video (or tear down if none) and re-apply appearance settings.
    private func refreshSurface() {
        let url = WallpaperResolver.video(
            for: primaryDisplayId,
            config: config,
            playlistOrder: playlistOrder,
            playlistAdvance: playlistAdvance
        )
        if let url {
            // set window behavior before showing so windows are created on the right Spaces.
            renderer.setShowOnAllSpaces(config.showOnAllSpaces)
            renderer.show(video: url)
            renderer.setFitMode(config.fitMode)
            renderer.setVolume(config.playbackSettings.volume)
            renderer.setDim(config.playbackSettings.dim)
            renderer.setSpeed(config.playbackSettings.speed)
            isShowing = true
        } else {
            renderer.hide()
            isShowing = false
            setPlaybackState(.idle)
        }
        // let the system-wallpaper stand-in match the current video and fit before taking over.
        systemWallpaper.setFitMode(config.fitMode)
        systemWallpaper.setStandIn(forVideo: isShowing ? url : nil)
        syncSystemWallpaper()
    }

    // take over the system wallpaper while a video is showing and the setting is on; restore
    // it otherwise. idempotent, so repeated refreshes do not thrash NSWorkspace.
    private func syncSystemWallpaper() {
        let shouldTakeOver = isShowing && config.replaceSystemWallpaper
        if shouldTakeOver && !didTakeOverSystemWallpaper {
            systemWallpaper.takeOver()
            didTakeOverSystemWallpaper = true
        } else if !shouldTakeOver && didTakeOverSystemWallpaper {
            systemWallpaper.restore()
            didTakeOverSystemWallpaper = false
        }
    }

    // the live surface currently applies one resolved video across displays; per-display
    // rendering is driven by the same resolver once the adapter supports distinct players.
    private let primaryDisplayId = "primary"

    private func applyPlayback() {
        guard isShowing else { setPlaybackState(.idle); return }
        let conditions = PlaybackConditions(
            hasVideo: true,
            isOccluded: environment.isOccluded,
            isFullscreenAppFrontmost: environment.isFullscreenAppFrontmost,
            isOnBattery: environment.isOnBattery,
            isDisplayAsleep: environment.isDisplayAsleep
        )
        let policy = PlaybackPolicy(pauseOnBattery: config.pauseOnBattery)
        switch policy.decide(conditions) {
        case .play:
            renderer.play()
            setPlaybackState(.playing)
        case .pause:
            renderer.pause()
            setPlaybackState(.paused)
        }
    }

    private func setPlaybackState(_ state: PlaybackState) {
        guard state != lastPlaybackState else { return }
        lastPlaybackState = state
        onPlaybackStateChanged?(state)
    }
}
