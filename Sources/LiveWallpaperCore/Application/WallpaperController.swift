import Foundation

// orchestrates the wallpaper: owns the current config and the latest environment signals,
// and drives the renderer through the playback policy. main-actor isolated: it runs on the
// main thread and drives main-actor renderer/store adapters.
@MainActor
public final class WallpaperController {
    private let store: ConfigStoring
    private let renderer: WallpaperRendering

    public private(set) var config: WallpaperConfig
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

    // user picked a new video: persist it, show it, and re-evaluate playback.
    public func selectVideo(_ url: URL) {
        config.selectedVideo = url
        store.save(config)
        refreshSurface()
        applyPlayback()
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

    // show or tear down the surface based on whether a video is selected.
    private func refreshSurface() {
        if let url = config.selectedVideo {
            renderer.show(video: url)
        } else {
            renderer.hide()
        }
    }

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
