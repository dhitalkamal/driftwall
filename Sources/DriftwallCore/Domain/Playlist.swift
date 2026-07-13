import Foundation

// an ordered set of videos to rotate through. intervalSeconds is clamped to a sane minimum
// so rotation cannot spin. shuffle is a user preference; the actual shuffled order is
// produced in the app layer (RNG is not available or wanted in pure core) and passed to
// RotationState, keeping this type and rotation deterministic and testable.
public struct Playlist: Codable, Equatable, Sendable {
    public let videos: [URL]
    public let shuffle: Bool
    public let intervalSeconds: Int

    public init(videos: [URL], shuffle: Bool, intervalSeconds: Int) {
        self.videos = videos
        self.shuffle = shuffle
        self.intervalSeconds = max(1, intervalSeconds)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let videos = try container.decode([URL].self, forKey: .videos)
        let shuffle = try container.decode(Bool.self, forKey: .shuffle)
        let interval = try container.decode(Int.self, forKey: .intervalSeconds)
        self.init(videos: videos, shuffle: shuffle, intervalSeconds: interval)
    }

    public var isEmpty: Bool { videos.isEmpty }
}

// resolves which video is current given a playlist, a play order (a permutation of indices),
// and how many times rotation has advanced. deterministic and RNG-free.
public enum RotationState {
    public static func currentVideo(playlist: Playlist, order: [Int], advanceCount: Int) -> URL? {
        guard !playlist.videos.isEmpty, !order.isEmpty else { return nil }
        let position = ((advanceCount % order.count) + order.count) % order.count
        let index = order[position]
        guard playlist.videos.indices.contains(index) else { return nil }
        return playlist.videos[index]
    }
}
