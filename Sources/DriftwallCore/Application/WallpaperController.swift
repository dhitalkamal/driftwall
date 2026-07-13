import Foundation

// orchestrates the wallpaper: owns the current config, the license tier, and the latest
// environment signals, and drives the renderer through the playback policy. main-actor
// isolated: it runs on the main thread and drives main-actor renderer/store adapters.
@MainActor
public final class WallpaperController {
    private let store: ConfigStoring
    private let renderer: WallpaperRendering

    public private(set) var config: WallpaperConfig
    public private(set) var tier: LicenseTier = .free
    private var environment: EnvironmentSignals

    public init(store: ConfigStoring, renderer: WallpaperRendering) {
        self.store = store
        self.renderer = renderer
        self.config = store.load()
        self.environment = EnvironmentSignals(
            isOccluded: false,
            isFullscreenAppFrontmost: false,
            isOnBattery: false
        )
    }

    // called once at launch: adopt the initial environment, restore the saved video, and
    // apply the playback decision.
    public func start(environment: EnvironmentSignals) {
        self.environment = environment
        config = store.load()
        refreshSurface()
        applyPlayback()
    }

    // the license tier, derived by the app layer from a verified license.
    public func setTier(_ tier: LicenseTier) {
        self.tier = tier
        refreshSurface()
        applyPlayback()
    }

    // user picked a new video: persist it, show it, and re-evaluate playback.
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
        store.save(config)
        refreshSurface()
    }

    // store a verified license token and its tier (the app layer verifies the signature).
    public func setLicense(token: String?, tier: LicenseTier) {
        config.licenseToken = token
        store.save(config)
        setTier(tier)
    }

    public func setFitMode(_ mode: FitMode) {
        config.fitMode = mode
        store.save(config)
        renderer.setFitMode(mode)
    }

    public func setPlaybackSettings(_ settings: PlaybackSettings) {
        config.playbackSettings = settings
        store.save(config)
        renderer.setVolume(settings.volume)
        renderer.setDim(settings.dim)
    }

    // user toggled whether playback pauses on battery.
    public func setPauseOnBattery(_ enabled: Bool) {
        config.pauseOnBattery = enabled
        store.save(config)
        applyPlayback()
    }

    // an environment signal changed (occlusion, fullscreen app, battery).
    public func updateEnvironment(_ environment: EnvironmentSignals) {
        self.environment = environment
        applyPlayback()
    }

    // show the resolved video (or tear down if none) and re-apply appearance settings.
    private func refreshSurface() {
        let url = WallpaperResolver.video(
            for: primaryDisplayId,
            config: config,
            tier: tier,
            playlistOrder: Array(config.playlist?.videos.indices ?? [].indices),
            playlistAdvance: 0
        )
        if let url {
            renderer.show(video: url)
            renderer.setFitMode(config.fitMode)
            renderer.setVolume(config.playbackSettings.volume)
            renderer.setDim(config.playbackSettings.dim)
        } else {
            renderer.hide()
        }
    }

    // the live surface currently applies one resolved video across displays; per-display
    // rendering is driven by the same resolver once the adapter supports distinct players.
    private let primaryDisplayId = "primary"

    private func applyPlayback() {
        guard config.hasVideo else { return }
        let conditions = PlaybackConditions(
            hasVideo: config.hasVideo,
            isOccluded: environment.isOccluded,
            isFullscreenAppFrontmost: environment.isFullscreenAppFrontmost,
            isOnBattery: environment.isOnBattery
        )
        let policy = PlaybackPolicy(pauseOnBattery: config.pauseOnBattery)
        switch policy.decide(conditions) {
        case .play:
            renderer.play()
        case .pause:
            renderer.pause()
        }
    }
}
