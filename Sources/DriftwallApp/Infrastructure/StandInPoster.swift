import AppKit
import AVFoundation
import DriftwallCore

// the desktop stand-in picture: a still frame of the current video, darkened by the wallpaper's
// dim and written as a png NSWorkspace can show. the decode and png encode run off the main
// actor; the frame is decoded once and re-darkened whenever the dim changes.
enum StandInPoster {
    // CGImage is immutable and thread-safe; box it so it can cross actor boundaries.
    struct Frame: @unchecked Sendable { let image: CGImage }

    // a still near the start of the video (0.1 s in skips a black first frame), no larger than
    // maxSize: the stand-in is only ever shown at display size. nil on failure.
    static func frame(for url: URL, maxSize: CGSize) async -> Frame? {
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = maxSize
        do {
            let result = try await generator.image(at: CMTime(seconds: 0.1, preferredTimescale: 600))
            return Frame(image: result.image)
        } catch {
            FileHandle.standardError.write(Data("Driftwall: failed to generate poster frame: \(error)\n".utf8))
            return nil
        }
    }

    // write the frame darkened by `dim` to directory/name and return its url, nil on failure.
    // callers alternate names so a re-dimmed picture gets a new url and macOS reloads it.
    static func write(_ frame: Frame, dim: Double, to directory: URL, name: String) async -> URL? {
        guard let dimmed = DimmedImage.make(frame.image, dim: dim),
              let png = NSBitmapImageRep(cgImage: dimmed).representation(using: .png, properties: [:]) else {
            return nil
        }
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let url = directory.appendingPathComponent(name)
            try png.write(to: url, options: .atomic)
            return url
        } catch {
            FileHandle.standardError.write(Data("Driftwall: failed to write poster frame: \(error)\n".utf8))
            return nil
        }
    }
}
