import AppKit
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

    func takeOver() {
        guard let blackout = ensureBlackoutImage() else { return }
        for screen in NSScreen.screens {
            guard let id = displayID(for: screen) else { continue }
            if saved[id] == nil {
                // desktopImageURL is nullable and may return our own blackout (e.g. left by a
                // crash). in either case do not take over this display: we would have no valid
                // original to restore.
                guard let current = NSWorkspace.shared.desktopImageURL(for: screen),
                      current.standardizedFileURL != blackout.standardizedFileURL else {
                    continue
                }
                saved[id] = current
            }
            setDesktopImage(blackout, for: screen)
        }
        persistSaved()
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
            try NSWorkspace.shared.setDesktopImageURL(url, for: screen, options: [:])
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
