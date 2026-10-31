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
        // each value falls back to its own default when missing or undecodable (speed was
        // also added later, so older configs omit it); init clamps the result.
        let volume = container.decodeLenient(Double.self, forKey: .volume) ?? 0
        let dim = container.decodeLenient(Double.self, forKey: .dim) ?? 0
        let speed = container.decodeLenient(Double.self, forKey: .speed) ?? 1.0
        self.init(volume: volume, dim: dim, speed: speed)
    }

    private static func clampUnit(_ value: Double) -> Double {
        min(1, max(0, value))
    }

    private static func clampSpeed(_ value: Double) -> Double {
        min(2.0, max(0.25, value))
    }
}
