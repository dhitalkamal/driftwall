import AppKit
import AVFoundation
import DriftwallCore

// takes over the macOS desktop picture while Driftwall is active so the system renders a
// trivial static image (no animated wallpaper burning power) behind our video, and restores
// the user's picture afterwards. uses only public NSWorkspace APIs.
//
// safety: the captured originals are also written to disk, so if the app crashes or is
// force-killed (applicationWillTerminate would not run) the next launch recovers the user's
// wallpaper via recoverIfNeeded(). the app's own blackout image and nil captures are never
// recorded as an "original", so an abnormal exit can never make blackout the saved wallpaper.
//
// limitations: NSWorkspace reads and writes only the active Space's picture, so takeover and
// restore apply per Space (documented in README). a display whose current wallpaper macOS
// cannot express as a URL is left untouched rather than blacked out.
@MainActor
final class SystemWallpaperController: SystemWallpaperControlling {
    private var saved: [CGDirectDisplayID: URL] = [:]
    private var blackoutURL: URL?
    // a still frame of the current video, used as the desktop stand-in so a Space switch shows
    // the video's frame instead of solid black. falls back to blackout until it is ready.
    private var standInURL: URL?
    private var posterVideoURL: URL?
    private var fitMode: FitMode = .fill
    // the undimmed poster frame, kept so a dim change re-darkens it without decoding again.
    private var posterFrame: StandInPoster.Frame?
    private var dim: Double = 0
    private var dimWork: DispatchWorkItem?
    // bumped on every poster write; a write that finishes after a newer one started is dropped.
    private var posterWrites = 0

    func setFitMode(_ mode: FitMode) {
        guard mode != fitMode else { return }
        fitMode = mode
        reapplyStandIn()  // re-scale the stand-in already on screen to the new fit mode.
    }

    // darken the stand-in to match the window's dim overlay. macOS draws the menu bar over the
    // desktop picture, not over our window, so an undimmed stand-in shows as a bright strip
    // under the menu bar. a slider drag sends many values, so re-render once it settles.
    func setDim(_ dim: Double) {
        let clamped = min(1, max(0, dim))
        guard clamped != self.dim else { return }
        self.dim = clamped
        dimWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated { self?.writePoster() }
        }
        dimWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: work)
    }

    // desktop-picture scaling that mirrors the video's fit mode, so revealing the stand-in
    // during a Space transition keeps the same framing (Fit stays letterboxed on black).
    private func desktopOptions() -> [NSWorkspace.DesktopImageOptionKey: Any] {
        switch fitMode {
        case .fill:
            return [.imageScaling: NSImageScaling.scaleProportionallyUpOrDown.rawValue,
                    .allowClipping: true]
        case .fit:
            return [.imageScaling: NSImageScaling.scaleProportionallyUpOrDown.rawValue,
                    .allowClipping: false,
                    .fillColor: NSColor.black]
        case .stretch:
            return [.imageScaling: NSImageScaling.scaleAxesIndependently.rawValue,
                    .allowClipping: true]
        }
    }

    // the image to place behind our video: the video poster frame if ready, else solid black.
    private func currentStandIn() -> URL? {
        standInURL ?? ensureBlackoutImage()
    }

    func setStandIn(forVideo url: URL?) {
        guard let url else {
            standInURL = nil
            posterVideoURL = nil
            posterFrame = nil
            return
        }
        guard posterVideoURL != url else { return }
        posterVideoURL = url
        let maxSize = maxDisplayPixelSize
        Task { [weak self] in
            let frame = await StandInPoster.frame(for: url, maxSize: maxSize)
            // ignore if the selected video changed while the poster was generating.
            guard let self, self.posterVideoURL == url else { return }
            self.posterFrame = frame
            self.writePoster()
        }
    }

    // write the poster darkened by the current dim, then show it on the displays we took
    // over (swapping out the black placeholder on first use). alternates between two file
    // names: macOS keeps showing a cached picture when the url does not change.
    private func writePoster() {
        guard let frame = posterFrame, let directory = supportDirectory else { return }
        posterWrites += 1
        let write = posterWrites
        let name = write % 2 == 0 ? "poster-a.png" : "poster-b.png"
        let dim = self.dim
        Task { [weak self] in
            let url = await StandInPoster.write(frame, dim: dim, to: directory, name: name)
            guard let self, self.posterWrites == write, let url else { return }
            self.standInURL = url
            self.reapplyStandIn()
        }
    }

    func takeOver() {
        guard let standIn = currentStandIn() else { return }
        for screen in NSScreen.screens {
            guard let id = displayID(for: screen) else { continue }
            if saved[id] == nil {
                // capture the real wallpaper to restore later. if the current picture is
                // already one of ours (e.g. a prior run was force-killed before restoring),
                // the real original is unknown; restore to a safe system image instead of
                // stranding our stand-in as the permanent wallpaper. if even that is missing,
                // leave this display untouched rather than risk a stuck stand-in.
                let current = NSWorkspace.shared.desktopImageURL(for: screen)
                if let current, !isOurImage(current) {
                    saved[id] = current
                } else if let fallback = safeFallbackWallpaper {
                    saved[id] = fallback
                } else {
                    continue
                }
            }
            setDesktopImage(standIn, for: screen)
        }
        persistSaved()
    }

    // the largest pixel size across all displays; the stand-in never needs more than this.
    private var maxDisplayPixelSize: CGSize {
        var size = CGSize(width: 1920, height: 1080)
        for screen in NSScreen.screens {
            let scale = screen.backingScaleFactor
            size.width = max(size.width, screen.frame.width * scale)
            size.height = max(size.height, screen.frame.height * scale)
        }
        return size
    }

    // a system image to restore to when the real original cannot be determined, so restore
    // never leaves one of our stand-ins as the wallpaper.
    private var safeFallbackWallpaper: URL? {
        let url = URL(fileURLWithPath: "/System/Library/Desktop Pictures/Solid Colors/Black.png")
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    // re-apply the current stand-in to displays we have already taken over (used when the
    // poster frame becomes available after an initial black takeover).
    private func reapplyStandIn() {
        guard !saved.isEmpty, let standIn = currentStandIn() else { return }
        for screen in NSScreen.screens {
            guard let id = displayID(for: screen), saved[id] != nil else { continue }
            setDesktopImage(standIn, for: screen)
        }
    }

    // replace a stale picture of ours on the active Space; user pictures are never replaced.
    func refreshActiveSpace() {
        guard !saved.isEmpty, let standIn = currentStandIn(), let directory = supportDirectory else { return }
        for screen in NSScreen.screens {
            guard let id = displayID(for: screen), saved[id] != nil else { continue }
            let current = NSWorkspace.shared.desktopImageURL(for: screen)
            if StandInFiles.needsRefresh(current: current, standIn: standIn, directory: directory) {
                setDesktopImage(standIn, for: screen)
            }
        }
    }

    func restore() {
        for screen in NSScreen.screens {
            guard let id = displayID(for: screen), let original = saved[id] else { continue }
            setDesktopImage(original, for: screen)
        }
        saved.removeAll()
        deletePersistedSaved()
    }

    // called once at launch, before any takeover. if a persisted map exists, the previous run
    // did not restore (crash / force quit), so put the user's wallpaper back.
    func recoverIfNeeded() {
        let persisted = loadPersistedSaved()
        guard !persisted.isEmpty else { return }
        for screen in NSScreen.screens {
            guard let id = displayID(for: screen), let original = persisted[id] else { continue }
            setDesktopImage(original, for: screen)
        }
        saved.removeAll()
        deletePersistedSaved()
    }

    private func setDesktopImage(_ url: URL, for screen: NSScreen) {
        do {
            try NSWorkspace.shared.setDesktopImageURL(url, for: screen, options: desktopOptions())
        } catch {
            FileHandle.standardError.write(
                Data("Driftwall: failed to set desktop image: \(error)\n".utf8)
            )
        }
    }

    private func displayID(for screen: NSScreen) -> CGDirectDisplayID? {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        return (screen.deviceDescription[key] as? NSNumber)?.uint32Value
    }

    // true for images we generated (blackout / poster), which live in our support directory.
    // never captured as a user "original".
    private func isOurImage(_ url: URL) -> Bool {
        guard let directory = supportDirectory else { return false }
        return StandInFiles.isOurs(url, directory: directory)
    }

    // MARK: - persistence

    private var supportDirectory: URL? {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        return base?.appendingPathComponent("Driftwall", isDirectory: true)
    }

    private var savedFileURL: URL? {
        supportDirectory?.appendingPathComponent("saved_wallpapers.json")
    }

    private func persistSaved() {
        guard let url = savedFileURL, let directory = supportDirectory else { return }
        let payload = Dictionary(uniqueKeysWithValues: saved.map { (String($0.key), $0.value.absoluteString) })
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(payload)
            try data.write(to: url, options: .atomic)
        } catch {
            FileHandle.standardError.write(
                Data("Driftwall: failed to persist saved wallpapers: \(error)\n".utf8)
            )
        }
    }

    private func loadPersistedSaved() -> [CGDirectDisplayID: URL] {
        guard let url = savedFileURL, FileManager.default.fileExists(atPath: url.path) else { return [:] }
        do {
            let data = try Data(contentsOf: url)
            let payload = try JSONDecoder().decode([String: String].self, from: data)
            var result: [CGDirectDisplayID: URL] = [:]
            for (key, value) in payload {
                if let id = CGDirectDisplayID(key), let original = URL(string: value) {
                    result[id] = original
                }
            }
            return result
        } catch {
            FileHandle.standardError.write(
                Data("Driftwall: failed to load saved wallpapers: \(error)\n".utf8)
            )
            return [:]
        }
    }

    private func deletePersistedSaved() {
        guard let url = savedFileURL else { return }
        try? FileManager.default.removeItem(at: url)
    }

    // create a small solid-black png once in application support and reuse it.
    private func ensureBlackoutImage() -> URL? {
        if let blackoutURL, FileManager.default.fileExists(atPath: blackoutURL.path) {
            return blackoutURL
        }
        guard let directory = supportDirectory else { return nil }
        let url = directory.appendingPathComponent("blackout.png")
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let size = NSSize(width: 128, height: 128)
            let image = NSImage(size: size)
            image.lockFocus()
            NSColor.black.setFill()
            NSRect(origin: .zero, size: size).fill()
            image.unlockFocus()
            guard let tiff = image.tiffRepresentation,
                  let rep = NSBitmapImageRep(data: tiff),
                  let png = rep.representation(using: .png, properties: [:]) else {
                return nil
            }
            try png.write(to: url, options: .atomic)
            blackoutURL = url
            return url
        } catch {
            FileHandle.standardError.write(
                Data("Driftwall: failed to create blackout image: \(error)\n".utf8)
            )
            return nil
        }
    }
}
