import CoreGraphics

// one on-screen window as reported by the window server. bounds use global window coordinates
// (top-left origin), the same space the displays passed to FullscreenDetector must use.
public struct WindowSnapshot: Equatable, Sendable {
    public var ownerPID: Int32
    public var layer: Int
    public var bounds: CGRect

    public init(ownerPID: Int32, layer: Int, bounds: CGRect) {
        self.ownerPID = ownerPID
        self.layer = layer
        self.bounds = bounds
    }
}

// one display in global window coordinates. topInset is the notch strip height (0 without a
// notch): native fullscreen windows on a notched panel start below it.
public struct DisplayGeometry: Equatable, Sendable {
    public var bounds: CGRect
    public var topInset: CGFloat

    public init(bounds: CGRect, topInset: CGFloat = 0) {
        self.bounds = bounds
        self.topInset = topInset
    }
}

public struct FullscreenState: Equatable, Sendable {
    // the frontmost app owns a window that fills a display.
    public var isFrontmost: Bool
    // every display is filled by some app's window, so the wallpaper is visible nowhere.
    public var coversEveryDisplay: Bool

    public init(isFrontmost: Bool, coversEveryDisplay: Bool) {
        self.isFrontmost = isFrontmost
        self.coversEveryDisplay = coversEveryDisplay
    }
}

// decides from a window list whether a fullscreen app is in front. a window counts as
// fullscreen when it sits at the normal app layer (0) and exactly fills a display, or the
// display minus its notch strip. native fullscreen and borderless fullscreen games both match;
// a zoomed window on a display without a notch does not, since it stops at the menu bar. on a
// notched display a zoomed window with the Dock hidden is indistinguishable from fullscreen
// and also matches, which is fine: it hides the wallpaper just as completely.
public enum FullscreenDetector {
    // reported bounds can be off by a fraction of a point on scaled displays, and on notched
    // panels safeAreaInsets reports the notch 1pt shorter than where fullscreen windows start.
    // still far below the menu bar height, so a zoomed window never sneaks in.
    private static let tolerance: CGFloat = 2

    public static func evaluate(
        windows: [WindowSnapshot],
        displays: [DisplayGeometry],
        frontmostPID: Int32?,
        ownPID: Int32
    ) -> FullscreenState {
        let candidates = windows.filter { $0.layer == 0 && $0.ownerPID != ownPID }
        let coveredBy: [[Int32]] = displays.map { display in
            candidates.filter { fills($0.bounds, display) }.map(\.ownerPID)
        }
        let isFrontmost = frontmostPID.map { pid in
            pid != ownPID && coveredBy.contains { $0.contains(pid) }
        } ?? false
        let coversEvery = !displays.isEmpty && coveredBy.allSatisfy { !$0.isEmpty }
        return FullscreenState(isFrontmost: isFrontmost, coversEveryDisplay: coversEvery)
    }

    // resolve a sample taken right at an active-Space change. the window list there still shows
    // the Space being left: entering fullscreen already reads as fullscreen, but leaving it also
    // still reads as fullscreen. an unchanged fullscreen sample is therefore stale and taken to
    // mean fullscreen ended, so the wallpaper resumes at once; the caller re-samples once the
    // transition settles to correct the rare swipe between two fullscreen Spaces.
    public static func afterSpaceChange(
        previous: FullscreenState, sampled: FullscreenState
    ) -> FullscreenState {
        let wasFullscreen = previous.isFrontmost || previous.coversEveryDisplay
        if wasFullscreen && sampled == previous {
            return FullscreenState(isFrontmost: false, coversEveryDisplay: false)
        }
        return sampled
    }

    private static func fills(_ window: CGRect, _ display: DisplayGeometry) -> Bool {
        if matches(window, display.bounds) { return true }
        guard display.topInset > 0 else { return false }
        var belowNotch = display.bounds
        belowNotch.origin.y += display.topInset
        belowNotch.size.height -= display.topInset
        return matches(window, belowNotch)
    }

    private static func matches(_ window: CGRect, _ display: CGRect) -> Bool {
        abs(window.minX - display.minX) <= tolerance
            && abs(window.minY - display.minY) <= tolerance
            && abs(window.width - display.width) <= tolerance
            && abs(window.height - display.height) <= tolerance
    }
}
