import AppKit
import UniformTypeIdentifiers
import DriftwallCore

// bridges the SwiftUI preferences view to the WallpaperController. holds published state for
// the controls and pushes changes through the controller (which persists them).
@MainActor
final class PreferencesModel: ObservableObject {
    private let controller: WallpaperController

    @Published var selectedVideoName: String
    @Published var fitMode: FitMode
    @Published var volume: Double
    @Published var dim: Double
    @Published var pauseOnBattery: Bool
    @Published var replaceSystemWallpaper: Bool
    @Published var showOnAllSpaces: Bool
    @Published var launchAtLogin: Bool
    @Published var tier: LicenseTier
    @Published var licenseKeyInput: String = ""
    @Published var licenseMessage: String = ""

    init(controller: WallpaperController) {
        self.controller = controller
        let config = controller.config
        selectedVideoName = config.selectedVideo?.lastPathComponent ?? "None"
        fitMode = config.fitMode
        volume = config.playbackSettings.volume
        dim = config.playbackSettings.dim
        pauseOnBattery = config.pauseOnBattery
        replaceSystemWallpaper = config.replaceSystemWallpaper
        showOnAllSpaces = config.showOnAllSpaces
        launchAtLogin = LaunchAtLoginService.isEnabled
        tier = controller.tier
    }

    var isPro: Bool { tier == .pro }

    var appVersion: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "0"
        let build = info?["CFBundleVersion"] as? String ?? "0"
        return "\(short) (\(build))"
    }

    func chooseVideo() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.movie, .mpeg4Movie, .quickTimeMovie]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.prompt = "Set Wallpaper"
        if panel.runModal() == .OK, let url = panel.url {
            controller.selectVideo(url)
            selectedVideoName = url.lastPathComponent
        }
    }

    func removeWallpaper() {
        controller.clearVideo()
        selectedVideoName = "None"
    }

    func updateFitMode(_ mode: FitMode) {
        fitMode = mode
        controller.setFitMode(mode)
    }

    func updatePlayback() {
        controller.setPlaybackSettings(PlaybackSettings(volume: volume, dim: dim))
    }

    func updatePauseOnBattery(_ enabled: Bool) {
        pauseOnBattery = enabled
        controller.setPauseOnBattery(enabled)
    }

    func updateReplaceSystemWallpaper(_ enabled: Bool) {
        replaceSystemWallpaper = enabled
        controller.setReplaceSystemWallpaper(enabled)
    }

    func updateShowOnAllSpaces(_ enabled: Bool) {
        showOnAllSpaces = enabled
        controller.setShowOnAllSpaces(enabled)
    }

    func updateLaunchAtLogin(_ enabled: Bool) {
        launchAtLogin = enabled
        LaunchAtLoginService.setEnabled(enabled)
    }

    func activateLicense() {
        let token = licenseKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else {
            licenseMessage = "Enter a license key."
            return
        }
        guard let claims = LicenseVerifier.verify(token: token) else {
            licenseMessage = "That license key is not valid."
            return
        }
        controller.setLicense(token: token, tier: claims.tier)
        tier = claims.tier
        licenseKeyInput = ""
        licenseMessage = "Activated. Thanks, \(claims.email)."
    }

    func deactivateLicense() {
        controller.setLicense(token: nil, tier: .free)
        tier = .free
        licenseMessage = "Deactivated. Pro features are locked."
    }
}
