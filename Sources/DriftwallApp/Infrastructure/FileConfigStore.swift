import Foundation
import DriftwallCore

// persists WallpaperConfig as json under Application Support. a missing file yields the
// default config; an unreadable one is copied to config.json.unreadable first, so the next
// save cannot destroy it. write failures are reported to stderr rather than swallowed.
@MainActor
final class FileConfigStore: ConfigStoring {
    private let fileURL: URL

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        let directory = base.appendingPathComponent("Driftwall", isDirectory: true)
        fileURL = directory.appendingPathComponent("config.json")
    }

    func load() -> WallpaperConfig {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return WallpaperConfig()
        }
        do {
            let data = try Data(contentsOf: fileURL)
            return try JSONDecoder().decode(WallpaperConfig.self, from: data)
        } catch {
            FileHandle.standardError.write(Data("Driftwall: failed to load config: \(error)\n".utf8))
            preserveUnreadableFile()
            return WallpaperConfig()
        }
    }

    // copies the unreadable file to config.json.unreadable (replacing any older copy) so the
    // next save of default settings cannot destroy the user's only copy.
    private func preserveUnreadableFile() {
        let backup = fileURL.appendingPathExtension("unreadable")
        do {
            try? FileManager.default.removeItem(at: backup)
            try FileManager.default.copyItem(at: fileURL, to: backup)
        } catch {
            FileHandle.standardError.write(Data("Driftwall: failed to back up unreadable config: \(error)\n".utf8))
        }
    }

    func save(_ config: WallpaperConfig) {
        do {
            let directory = fileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(config)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            FileHandle.standardError.write(Data("Driftwall: failed to save config: \(error)\n".utf8))
        }
    }
}
