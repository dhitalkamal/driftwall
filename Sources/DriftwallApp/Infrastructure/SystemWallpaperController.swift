import AppKit
import DriftwallCore

// takes over the macOS desktop picture while Driftwall is active so the system renders a
// trivial static image (no animated wallpaper burning power) behind our video, and restores
// the user's picture afterwards. uses only public NSWorkspace APIs.
//
// limitation: if a display currently shows a native video wallpaper, macOS hands back only a
// static representation to restore. static and dynamic .heic wallpapers restore exactly.
@MainActor
final class SystemWallpaperController: SystemWallpaperControlling {
    // remembered desktop image url per display, captured at takeover.
    private var saved: [CGDirectDisplayID: URL] = [:]
    private var blackoutURL: URL?

    func takeOver() {
        guard let blackout = ensureBlackoutImage() else { return }
        for screen in NSScreen.screens {
            guard let id = displayID(for: screen) else { continue }
            if saved[id] == nil {
                saved[id] = NSWorkspace.shared.desktopImageURL(for: screen)
            }
            setDesktopImage(blackout, for: screen)
        }
    }

    func restore() {
        for screen in NSScreen.screens {
            guard let id = displayID(for: screen), let original = saved[id] else { continue }
            setDesktopImage(original, for: screen)
        }
        saved.removeAll()
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

    // create a small solid-black png once in application support and reuse it.
    private func ensureBlackoutImage() -> URL? {
        if let blackoutURL, FileManager.default.fileExists(atPath: blackoutURL.path) {
            return blackoutURL
        }
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        guard let directory = base?.appendingPathComponent("Driftwall", isDirectory: true) else { return nil }
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
