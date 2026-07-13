import Foundation

// orchestrates the wallpaper: owns the current config, the license tier, and the latest
// environment signals, and drives the renderer through the playback policy. main-actor
// isolated: it runs on the main thread and drives main-actor renderer/store adapters.
@MainActor
public final class WallpaperController {
    private let store: ConfigStoring
    private let renderer: WallpaperRendering
    private let systemWallpaper: SystemWallpaperControlling

    public private(set) var config: WallpaperConfig
    public private(set) var tier: LicenseTier = .free
    private var environment: EnvironmentSignals
    private var isShowing = false
    private var didTakeOverSystemWallpaper = false

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
            // set window behavior before showing so windows are created on the right Spaces.
            renderer.setShowOnAllSpaces(config.showOnAllSpaces)
            renderer.show(video: url)
            renderer.setFitMode(config.fitMode)
            renderer.setVolume(config.playbackSettings.volume)
            renderer.setDim(config.playbackSettings.dim)
            isShowing = true
        } else {
            renderer.hide()
            isShowing = false
        }
        // let the system-wallpaper stand-in match the current video before taking over.
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
