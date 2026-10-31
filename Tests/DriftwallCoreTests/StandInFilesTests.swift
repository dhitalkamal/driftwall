import Foundation
import DriftwallCore

private let ours = URL(fileURLWithPath: "/Users/me/Library/Application Support/Driftwall", isDirectory: true)
private func file(_ path: String) -> URL { URL(fileURLWithPath: path) }

@MainActor
func runStandInFilesTests(_ t: TestRunner) {
    let current = file("/Users/me/Library/Application Support/Driftwall/poster-b.png")
    let stale = file("/Users/me/Library/Application Support/Driftwall/poster.png")
    let user = file("/Users/me/Pictures/beach.jpg")
    // a sibling folder whose name merely starts with ours is not ours.
    let sibling = file("/Users/me/Library/Application Support/Driftwall Backup/poster.png")

    t.expect(StandInFiles.isOurs(stale, directory: ours), "a file in our folder is ours")
    t.expect(!StandInFiles.isOurs(user, directory: ours), "a user picture is not ours")
    t.expect(!StandInFiles.isOurs(sibling, directory: ours), "a sibling folder with a longer name is not ours")
    t.expect(!StandInFiles.isOurs(ours, directory: ours), "the folder itself is not a picture of ours")

    // a Space showing an older stand-in of ours gets the current one ...
    t.expect(StandInFiles.needsRefresh(current: stale, standIn: current, directory: ours), "stale stand-in is refreshed")
    // ... but the current stand-in, the user's own pictures and unknown pictures are left alone.
    t.expect(!StandInFiles.needsRefresh(current: current, standIn: current, directory: ours), "current stand-in is kept")
    t.expect(!StandInFiles.needsRefresh(current: user, standIn: current, directory: ours), "user picture is never replaced")
    t.expect(!StandInFiles.needsRefresh(current: sibling, standIn: current, directory: ours), "sibling folder picture is never replaced")
    t.expect(!StandInFiles.needsRefresh(current: nil, standIn: current, directory: ours), "unknown picture is left alone")

    // after a takeover, every Space switch asks the stand-in side to refresh the active Space.
    let system = FakeSystemWallpaper()
    let store = FakeStore(WallpaperConfig(selectedVideo: file("/tmp/loop.mp4")))
    let controller = WallpaperController(store: store, renderer: FakeRenderer(), systemWallpaper: system)
    controller.start(environment: EnvironmentSignals(isOccluded: false, isFullscreenAppFrontmost: false, isOnBattery: false))
    controller.handleSpaceChanged()
    controller.handleSpaceChanged()
    t.expectEqual(system.activeSpaceRefreshes, 2)

    // with desktop-picture takeover turned off, Space switches leave pictures alone.
    let offSystem = FakeSystemWallpaper()
    let offStore = FakeStore(WallpaperConfig(selectedVideo: file("/tmp/loop.mp4"), replaceSystemWallpaper: false))
    let off = WallpaperController(store: offStore, renderer: FakeRenderer(), systemWallpaper: offSystem)
    off.start(environment: EnvironmentSignals(isOccluded: false, isFullscreenAppFrontmost: false, isOnBattery: false))
    off.handleSpaceChanged()
    t.expectEqual(offSystem.activeSpaceRefreshes, 0)
}
