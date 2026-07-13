// how the video is scaled to fill a display. maps to an AVLayerVideoGravity in the adapter.
public enum FitMode: String, Codable, Sendable, CaseIterable {
    case fill
    case fit
    case stretch
    case center

    public static let `default` = FitMode.fill
}
