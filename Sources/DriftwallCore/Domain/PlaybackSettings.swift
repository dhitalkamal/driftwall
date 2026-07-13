// user-tunable playback settings. volume and dim are clamped to 0...1 on construction so
// out-of-range persisted values can never reach the player or the dim overlay.
public struct PlaybackSettings: Codable, Equatable, Sendable {
    public let volume: Double
    public let dim: Double

    public init(volume: Double = 0, dim: Double = 0) {
        self.volume = PlaybackSettings.clamp(volume)
        self.dim = PlaybackSettings.clamp(dim)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let volume = try container.decode(Double.self, forKey: .volume)
        let dim = try container.decode(Double.self, forKey: .dim)
        self.init(volume: volume, dim: dim)
    }

    private static func clamp(_ value: Double) -> Double {
        min(1, max(0, value))
    }
}
