import Foundation

// facts about a video file shown in Preferences, and their display text. every field is
// optional because AVFoundation can fail to report any one of them; unknown parts are left
// out of the text rather than shown as placeholders.
public struct VideoDetails: Equatable, Sendable {
    public var pixelWidth: Int?
    public var pixelHeight: Int?
    public var durationSeconds: Double?
    public var byteCount: Int64?

    public init(
        pixelWidth: Int? = nil,
        pixelHeight: Int? = nil,
        durationSeconds: Double? = nil,
        byteCount: Int64? = nil
    ) {
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.durationSeconds = durationSeconds
        self.byteCount = byteCount
    }

    // one line under the preview, e.g. "3840 x 2160, 42 s loop, 186 MB".
    public var summary: String {
        var parts: [String] = []
        if let pixelWidth, let pixelHeight {
            parts.append("\(pixelWidth) x \(pixelHeight)")
        }
        if let seconds = wholeSeconds {
            parts.append(seconds < 60 ? "\(seconds) s loop" : "\(Self.clock(seconds)) loop")
        }
        if let byteCount {
            parts.append(Self.size(byteCount))
        }
        return parts.joined(separator: ", ")
    }

    // clock-style loop length for playlist rows, e.g. "0:42" or "1:02:03".
    public var loopLength: String? {
        wholeSeconds.map(Self.clock)
    }

    // duration rounded to the nearest second, nil when unknown or not a usable length.
    private var wholeSeconds: Int? {
        guard let durationSeconds, durationSeconds.isFinite, durationSeconds > 0 else { return nil }
        return Int(durationSeconds.rounded())
    }

    private static func clock(_ seconds: Int) -> String {
        let h = seconds / 3600, m = (seconds % 3600) / 60, s = seconds % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%d:%02d", m, s)
    }

    // decimal units, matching what Finder shows for the same file.
    private static func size(_ bytes: Int64) -> String {
        let value = Double(bytes)
        if value >= 1e9 { return String(format: "%.1f GB", (value / 1e8).rounded() / 10) }
        if value >= 1e6 { return "\(Int((value / 1e6).rounded())) MB" }
        return "\(max(1, Int((value / 1e3).rounded()))) KB"
    }
}
