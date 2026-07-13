// how the video is scaled to fill a display. maps to an AVLayerVideoGravity in the adapter:
// fill = aspect fill (crop), fit = aspect fit (letterbox), stretch = fill ignoring aspect.
public enum FitMode: String, Codable, Sendable, CaseIterable {
    case fill
    case fit
    case stretch

    public static let `default` = FitMode.fill
}
