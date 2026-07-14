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
    @Published var speed: Double
    @Published var playlistVideos: [URL]
    @Published var playlistShuffle: Bool
    @Published var playlistIntervalMinutes: Int
    @Published var playlistEnabled: Bool
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
        speed = config.playbackSettings.speed
        playlistVideos = config.playlist?.videos ?? []
        playlistShuffle = config.playlist?.shuffle ?? false
        playlistIntervalMinutes = max(1, (config.playlist?.intervalSeconds ?? 300) / 60)
        playlistEnabled = config.playlistEnabled
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
        controller.setPlaybackSettings(PlaybackSettings(volume: volume, dim: dim, speed: speed))
    }

    // MARK: - playlist (pro)

    var playlistVideoNames: [String] { playlistVideos.map { $0.lastPathComponent } }

    func addPlaylistVideos() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.movie, .mpeg4Movie, .quickTimeMovie]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.prompt = "Add to Playlist"
        if panel.runModal() == .OK {
            playlistVideos.append(contentsOf: panel.urls)
            commitPlaylist()
        }
    }

    func removePlaylistVideo(at index: Int) {
        guard playlistVideos.indices.contains(index) else { return }
        playlistVideos.remove(at: index)
        commitPlaylist()
    }

    func updatePlaylistShuffle(_ shuffle: Bool) {
        playlistShuffle = shuffle
        commitPlaylist()
    }

    func updatePlaylistInterval(_ minutes: Int) {
        playlistIntervalMinutes = max(1, minutes)
        commitPlaylist()
    }

    func updatePlaylistEnabled(_ enabled: Bool) {
        playlistEnabled = enabled
        controller.setPlaylistEnabled(enabled)
    }

    private func commitPlaylist() {
        let playlist = Playlist(
            videos: playlistVideos,
            shuffle: playlistShuffle,
            intervalSeconds: playlistIntervalMinutes * 60
        )
        controller.setPlaylist(playlist)
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

    // fill the license field directly from the clipboard, so paste works with one click even
    // if a keyboard shortcut does not reach the field.
    func pasteLicenseFromClipboard() {
        if let text = NSPasteboard.general.string(forType: .string) {
            licenseKeyInput = text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
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
