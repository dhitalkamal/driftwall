import Foundation
import DriftwallCore

func runRotationTests(_ t: TestRunner) {
    let v0 = URL(fileURLWithPath: "/tmp/0.mp4")
    let v1 = URL(fileURLWithPath: "/tmp/1.mp4")
    let v2 = URL(fileURLWithPath: "/tmp/2.mp4")

    // empty playlist yields no current video.
    let empty = Playlist(videos: [], shuffle: false, intervalSeconds: 30)
    t.expect(RotationState.currentVideo(playlist: empty, order: [], advanceCount: 0) == nil,
             "empty playlist has no current video")

    // single-video playlist always returns that video regardless of advances.
    let single = Playlist(videos: [v0], shuffle: false, intervalSeconds: 30)
    t.expectEqual(RotationState.currentVideo(playlist: single, order: [0], advanceCount: 0), v0)
    t.expectEqual(RotationState.currentVideo(playlist: single, order: [0], advanceCount: 5), v0)

    // three videos, natural order, cycles v0,v1,v2,v0 as it advances.
    let three = Playlist(videos: [v0, v1, v2], shuffle: false, intervalSeconds: 30)
    let natural = [0, 1, 2]
    t.expectEqual(RotationState.currentVideo(playlist: three, order: natural, advanceCount: 0), v0)
    t.expectEqual(RotationState.currentVideo(playlist: three, order: natural, advanceCount: 1), v1)
    t.expectEqual(RotationState.currentVideo(playlist: three, order: natural, advanceCount: 2), v2)
    t.expectEqual(RotationState.currentVideo(playlist: three, order: natural, advanceCount: 3), v0)

    // a shuffled order is honored: the caller supplies the permutation, core just indexes it.
    let shuffled = [2, 0, 1]
    t.expectEqual(RotationState.currentVideo(playlist: three, order: shuffled, advanceCount: 0), v2)
    t.expectEqual(RotationState.currentVideo(playlist: three, order: shuffled, advanceCount: 1), v0)
    t.expectEqual(RotationState.currentVideo(playlist: three, order: shuffled, advanceCount: 3), v2)

    // intervalSeconds is clamped to at least 1 so rotation cannot spin.
    let tiny = Playlist(videos: [v0], shuffle: false, intervalSeconds: 0)
    t.expect(tiny.intervalSeconds >= 1, "interval should be clamped to a sane minimum")
}
