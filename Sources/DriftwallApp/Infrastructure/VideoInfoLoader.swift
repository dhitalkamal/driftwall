import AVFoundation
import AppKit
import DriftwallCore

// reads facts and a still frame from a video file for Preferences. the work runs off the main
// actor; callers hop back to publish the results.
enum VideoInfoLoader {
    // CGImage is immutable and thread-safe; box it so it can cross the actor boundary.
    struct Still: @unchecked Sendable { let image: CGImage }

    static func details(for url: URL) async -> VideoDetails {
        var details = VideoDetails()
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        if let size = attributes?[.size] as? NSNumber {
            details.byteCount = size.int64Value
        }
        let asset = AVURLAsset(url: url)
        if let duration = try? await asset.load(.duration) {
            details.durationSeconds = duration.seconds
        }
        // apply the track transform so a portrait recording reports portrait dimensions.
        if let track = try? await asset.loadTracks(withMediaType: .video).first,
           let loaded = try? await track.load(.naturalSize, .preferredTransform) {
            let rect = CGRect(origin: .zero, size: loaded.0).applying(loaded.1)
            details.pixelWidth = Int(abs(rect.width).rounded())
            details.pixelHeight = Int(abs(rect.height).rounded())
        }
        return details
    }

    // an early frame (0.1 s in skips a black first frame), capped to maxSize.
    static func still(for url: URL, maxSize: CGSize) async -> Still? {
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = maxSize
        guard let frame = try? await generator.image(at: CMTime(seconds: 0.1, preferredTimescale: 600)) else {
            return nil
        }
        return Still(image: frame.image)
    }
}
