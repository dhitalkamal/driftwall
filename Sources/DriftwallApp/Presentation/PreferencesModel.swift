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
    @Published var fullscreenBehavior: FullscreenBehavior
    @Published var launchAtLogin: Bool
    @Published var previewImage: NSImage?
    // one-line facts about the chosen video, e.g. "3840 x 2160, 42 s loop, 186 MB".
    @Published var videoDetails = ""
    // per-video thumbnails and loop lengths for the playlist rows, filled in as they load.
    @Published var playlistStills: [URL: NSImage] = [:]
    @Published var playlistLengths: [URL: String] = [:]
    // playlist videos whose info is loading, so a list edit mid-load does not start a second load.
    private var loadingInfo: Set<URL> = []

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
        fullscreenBehavior = config.fullscreenBehavior
        launchAtLogin = LaunchAtLoginService.isEnabled
        refreshPreview()
        loadPlaylistInfo()
    }

    // the still and the details line for the chosen video, shown on the Wallpaper tab.
    private func refreshPreview() {
        guard let url = controller.config.selectedVideo else {
            previewImage = nil
            videoDetails = ""
            return
        }
        Task { [weak self] in
            let still = await VideoInfoLoader.still(for: url, maxSize: CGSize(width: 1280, height: 800))
            let details = await VideoInfoLoader.details(for: url)
            // a newer choice may have landed while this one loaded; drop stale results.
            guard let self, self.controller.config.selectedVideo == url else { return }
            self.previewImage = still.map { NSImage(cgImage: $0.image, size: .zero) }
            self.videoDetails = details.summary
        }
    }

    // the video on the desktop right now, which may be a playlist item rather than the chosen
    // single video. read when the view renders, so a playlist row can be marked as playing.
    var currentVideoURL: URL? { controller.currentVideoURL }

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
        videoDetails = ""
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
        let contents = (try? FileManager.default.contentsOfDirectory(
            at: folder, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]
        )) ?? []
        return contents
            .filter(VideoFileTypes.isSupported)
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

    // load thumbnails and loop lengths for playlist videos that do not have them yet.
    private func loadPlaylistInfo() {
        for url in playlistVideos where playlistStills[url] == nil && !loadingInfo.contains(url) {
            loadingInfo.insert(url)
            Task { [weak self] in
                let still = await VideoInfoLoader.still(for: url, maxSize: CGSize(width: 160, height: 100))
                let details = await VideoInfoLoader.details(for: url)
                guard let self else { return }
                self.loadingInfo.remove(url)
                if let still { self.playlistStills[url] = NSImage(cgImage: still.image, size: .zero) }
                self.playlistLengths[url] = details.loopLength
            }
        }
    }

    private func commitPlaylist() {
        let playlist = Playlist(
            videos: playlistVideos,
            shuffle: playlistShuffle,
            intervalSeconds: playlistIntervalMinutes * 60
        )
        controller.setPlaylist(playlist)
        loadPlaylistInfo()
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

    func updateFullscreenBehavior(_ behavior: FullscreenBehavior) {
        fullscreenBehavior = behavior
        controller.setFullscreenBehavior(behavior)
    }

    func showLog() {
        Diagnostics.revealInFinder()
    }

    func updateLaunchAtLogin(_ enabled: Bool) {
        launchAtLogin = enabled
        LaunchAtLoginService.setEnabled(enabled)
    }
}
