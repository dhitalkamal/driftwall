import Foundation

// rules for the desktop pictures Driftwall generates (blackout, posters), which all live in its
// support folder. used to never capture one of ours as the user's original, and to replace a
// stale one of ours left on another Space, while never touching the user's own pictures.
public enum StandInFiles {
    // true for a file inside our folder. compares whole path components, so a sibling folder
    // whose name only starts with ours ("Driftwall Backup") does not count.
    public static func isOurs(_ url: URL, directory: URL) -> Bool {
        let file = url.standardizedFileURL.pathComponents
        let folder = directory.standardizedFileURL.pathComponents
        return file.count > folder.count && Array(file.prefix(folder.count)) == folder
    }

    // true when a Space shows one of our pictures that is not the current stand-in (an older
    // poster, an undimmed one, or the black placeholder), so it should be replaced.
    public static func needsRefresh(current: URL?, standIn: URL, directory: URL) -> Bool {
        guard let current, isOurs(current, directory: directory) else { return false }
        return current.standardizedFileURL != standIn.standardizedFileURL
    }
}
