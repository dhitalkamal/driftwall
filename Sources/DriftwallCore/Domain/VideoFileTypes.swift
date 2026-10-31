import Foundation

// the video files Driftwall accepts from a drop or a folder import. checked by extension so a
// stray document never replaces a working wallpaper; a file that has a video extension but
// still cannot play is caught later by the player's load-failure report.
public enum VideoFileTypes {
    public static let extensions: Set<String> = ["mp4", "m4v", "mov"]

    public static func isSupported(_ url: URL) -> Bool {
        !url.hasDirectoryPath && extensions.contains(url.pathExtension.lowercased())
    }
}
