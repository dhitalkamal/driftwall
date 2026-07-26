import AppKit
import AVFoundation
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
    @Published var previewImage: NSImage?

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
        refreshPreview()
    }

    // a still thumbnail of the current video, shown in the Wallpaper section.
    private struct Thumb: @unchecked Sendable { let cg: CGImage }

    private func refreshPreview() {
        guard let url = controller.config.selectedVideo else {
            previewImage = nil
            return
        }
        Task { [weak self] in
            let thumb = await Self.thumbnail(for: url)
            await MainActor.run {
                self?.previewImage = thumb.map { NSImage(cgImage: $0.cg, size: .zero) }
            }
        }
    }

    private nonisolated static func thumbnail(for url: URL) async -> Thumb? {
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 640, height: 400)
        guard let frame = try? await generator.image(at: CMTime(seconds: 0.1, preferredTimescale: 600)) else {
            return nil
        }
        return Thumb(cg: frame.image)
    }

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
            setVideo(url)
        }
    }

    // set the wallpaper video (used by the picker and by drag-and-drop onto the preview).
    func setVideo(_ url: URL) {
        controller.selectVideo(url)
        selectedVideoName = url.lastPathComponent
        refreshPreview()
    }

    func removeWallpaper() {
        controller.clearVideo()
        selectedVideoName = "None"
        previewImage = nil
    }

    func updateFitMode(_ mode: FitMode) {
        fitMode = mode
        controller.setFitMode(mode)
    }

    func updatePlayback() {
        controller.setPlaybackSettings(PlaybackSettings(volume: volume, dim: dim, speed: speed))
    }

    // MARK: - playlist

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

    // add every video file directly inside a chosen folder to the playlist, sorted by name.
    func addPlaylistFolder() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.prompt = "Add Folder"
        guard panel.runModal() == .OK, let folder = panel.url else { return }
        let videos = Self.videoFiles(in: folder)
        guard !videos.isEmpty else { return }
        playlistVideos.append(contentsOf: videos)
        commitPlaylist()
    }

    private static func videoFiles(in folder: URL) -> [URL] {
        let extensions: Set<String> = ["mp4", "m4v", "mov"]
        let contents = (try? FileManager.default.contentsOfDirectory(
            at: folder, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]
        )) ?? []
        return contents
            .filter { extensions.contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
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
}
