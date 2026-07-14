// user-tunable playback settings. volume and dim are clamped to 0...1 and speed to
// 0.25...2.0 on construction so out-of-range persisted values can never reach the player.
public struct PlaybackSettings: Codable, Equatable, Sendable {
    public let volume: Double
    public let dim: Double
    public let speed: Double

    public init(volume: Double = 0, dim: Double = 0, speed: Double = 1.0) {
        self.volume = PlaybackSettings.clampUnit(volume)
        self.dim = PlaybackSettings.clampUnit(dim)
        self.speed = PlaybackSettings.clampSpeed(speed)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let volume = try container.decode(Double.self, forKey: .volume)
        let dim = try container.decode(Double.self, forKey: .dim)
        // speed was added later; tolerate older configs that omit it.
        let speed = try container.decodeIfPresent(Double.self, forKey: .speed) ?? 1.0
        self.init(volume: volume, dim: dim, speed: speed)
    }

    private static func clampUnit(_ value: Double) -> Double {
        min(1, max(0, value))
    }

    private static func clampSpeed(_ value: Double) -> Double {
        min(2.0, max(0.25, value))
    }
}
