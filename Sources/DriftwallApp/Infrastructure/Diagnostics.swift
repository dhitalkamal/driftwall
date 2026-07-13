import Foundation

// lightweight append-only diagnostics log at
// ~/Library/Application Support/Driftwall/diagnostics.log. used to capture the wallpaper's
// state around Space changes so a hard-to-reproduce black-on-return can be diagnosed from a
// real machine instead of guessed at.
enum Diagnostics {
    private static var fileURL: URL? {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        return base?.appendingPathComponent("Driftwall/diagnostics.log")
    }

    static func log(_ message: String) {
        guard let url = fileURL else { return }
        let stamp = ISO8601DateFormatter().string(from: Date())
        let data = Data("[\(stamp)] \(message)\n".utf8)
        let directory = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        if let handle = try? FileHandle(forWritingTo: url) {
            handle.seekToEndOfFile()
            handle.write(data)
            try? handle.close()
        } else {
            try? data.write(to: url)
        }
    }
}
