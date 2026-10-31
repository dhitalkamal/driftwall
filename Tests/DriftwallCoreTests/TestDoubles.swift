import Foundation
import DriftwallCore

// records what the controller asks the wallpaper surface to do.
@MainActor
final class FakeRenderer: WallpaperRendering {
    var shownVideos: [URL] = []
    var commands: [String] = []
    var fitMode: FitMode?
    var volume: Double?
    var dim: Double?
    var speed: Double?
    var showOnAllSpaces: Bool?
    var refreshCount = 0
    var events: [String] = []
    func refresh() { refreshCount += 1 }
    func show(video url: URL) { shownVideos.append(url); events.append("show") }
    func play() { commands.append("play") }
    func pause() { commands.append("pause") }
    func hide() { commands.append("hide"); events.append("hide") }
    func setFitMode(_ mode: FitMode) { fitMode = mode }
    func setVolume(_ volume: Double) { self.volume = volume }
    func setDim(_ dim: Double) { self.dim = dim }
    func setSpeed(_ rate: Double) { speed = rate }
    func setShowOnAllSpaces(_ enabled: Bool) { showOnAllSpaces = enabled; events.append("spaces:\(enabled)") }
    var lastCommand: String? { commands.last }
    var lastShown: URL? { shownVideos.last }
}

@MainActor
final class FakeStore: ConfigStoring {
    var stored: WallpaperConfig
    var saveCount = 0
    init(_ config: WallpaperConfig = WallpaperConfig()) { stored = config }
    func load() -> WallpaperConfig { stored }
    func save(_ config: WallpaperConfig) { stored = config; saveCount += 1 }
}

@MainActor
final class FakeSystemWallpaper: SystemWallpaperControlling {
    var takeOverCount = 0
    var restoreCount = 0
    var standInVideos: [URL?] = []
    func setStandIn(forVideo url: URL?) { standInVideos.append(url) }
    var dims: [Double] = []
    func setFitMode(_ mode: FitMode) {}
    func setDim(_ dim: Double) { dims.append(dim) }
    func takeOver() { takeOverCount += 1 }
    func restore() { restoreCount += 1 }
}

let clearEnv = EnvironmentSignals(
    isOccluded: false,
    isFullscreenAppFrontmost: false,
    isOnBattery: false
)

let sampleVideo = URL(fileURLWithPath: "/tmp/loop.mp4")
