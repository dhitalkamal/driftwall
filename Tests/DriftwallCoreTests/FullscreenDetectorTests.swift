import CoreGraphics
import DriftwallCore

// two side by side displays in global window coordinates (top-left origin), no notch.
private let leftRect = CGRect(x: 0, y: 0, width: 1512, height: 982)
private let rightRect = CGRect(x: 1512, y: 0, width: 2560, height: 1440)
private let left = DisplayGeometry(bounds: leftRect)
private let right = DisplayGeometry(bounds: rightRect)
// a notched laptop panel: native fullscreen windows sit below the 33pt notch strip.
private let notched = DisplayGeometry(bounds: leftRect, topInset: 33)
private let belowNotch = CGRect(x: 0, y: 33, width: 1512, height: 949)
private let ownPID: Int32 = 1
private let appPID: Int32 = 42
private let otherPID: Int32 = 77

private func window(_ pid: Int32, _ bounds: CGRect, layer: Int = 0) -> WindowSnapshot {
    WindowSnapshot(ownerPID: pid, layer: layer, bounds: bounds)
}

func runFullscreenDetectorTests(_ t: TestRunner) {
    // nothing fullscreen: ordinary windows smaller than the screen.
    t.expectEqual(
        FullscreenDetector.evaluate(
            windows: [window(appPID, CGRect(x: 100, y: 100, width: 800, height: 600))],
            displays: [left], frontmostPID: appPID, ownPID: ownPID),
        FullscreenState(isFrontmost: false, coversEveryDisplay: false))

    // on a display without a notch, a zoomed window stops at the menu bar: not fullscreen.
    t.expectEqual(
        FullscreenDetector.evaluate(
            windows: [window(appPID, CGRect(x: 0, y: 33, width: 1512, height: 949))],
            displays: [left], frontmostPID: appPID, ownPID: ownPID),
        FullscreenState(isFrontmost: false, coversEveryDisplay: false))

    // single display: the frontmost app fills the screen.
    t.expectEqual(
        FullscreenDetector.evaluate(
            windows: [window(appPID, leftRect)],
            displays: [left], frontmostPID: appPID, ownPID: ownPID),
        FullscreenState(isFrontmost: true, coversEveryDisplay: true))

    // two displays, fullscreen on one only.
    t.expectEqual(
        FullscreenDetector.evaluate(
            windows: [window(appPID, rightRect), window(otherPID, CGRect(x: 10, y: 40, width: 500, height: 400))],
            displays: [left, right], frontmostPID: appPID, ownPID: ownPID),
        FullscreenState(isFrontmost: true, coversEveryDisplay: false))

    // two displays, each with a fullscreen app, a different one frontmost.
    t.expectEqual(
        FullscreenDetector.evaluate(
            windows: [window(appPID, rightRect), window(otherPID, leftRect)],
            displays: [left, right], frontmostPID: otherPID, ownPID: ownPID),
        FullscreenState(isFrontmost: true, coversEveryDisplay: true))

    // fullscreen app exists but another (windowed) app is frontmost: not frontmost.
    t.expectEqual(
        FullscreenDetector.evaluate(
            windows: [window(appPID, rightRect)],
            displays: [left, right], frontmostPID: otherPID, ownPID: ownPID),
        FullscreenState(isFrontmost: false, coversEveryDisplay: false))

    // our own windows and non-zero-layer windows (desktop, overlays) never count.
    t.expectEqual(
        FullscreenDetector.evaluate(
            windows: [window(ownPID, leftRect), window(otherPID, leftRect, layer: -2147483623), window(otherPID, leftRect, layer: 25)],
            displays: [left], frontmostPID: otherPID, ownPID: ownPID),
        FullscreenState(isFrontmost: false, coversEveryDisplay: false))

    // tiny rounding differences in reported bounds still match the display.
    t.expectEqual(
        FullscreenDetector.evaluate(
            windows: [window(appPID, CGRect(x: 0, y: 0, width: 1512.4, height: 981.6))],
            displays: [left], frontmostPID: appPID, ownPID: ownPID),
        FullscreenState(isFrontmost: true, coversEveryDisplay: true))

    // no displays known: never claim everything is covered.
    t.expectEqual(
        FullscreenDetector.evaluate(windows: [], displays: [], frontmostPID: appPID, ownPID: ownPID),
        FullscreenState(isFrontmost: false, coversEveryDisplay: false))

    // notched display: a native fullscreen window below the notch counts (measured live on a
    // notched MacBook), as does an app that opts into drawing behind the notch.
    t.expectEqual(
        FullscreenDetector.evaluate(
            windows: [window(appPID, belowNotch)],
            displays: [notched], frontmostPID: appPID, ownPID: ownPID),
        FullscreenState(isFrontmost: true, coversEveryDisplay: true))
    t.expectEqual(
        FullscreenDetector.evaluate(
            windows: [window(appPID, leftRect)],
            displays: [notched], frontmostPID: appPID, ownPID: ownPID),
        FullscreenState(isFrontmost: true, coversEveryDisplay: true))

    // measured live: safeAreaInsets reports a 32pt notch while the fullscreen window starts at
    // 33pt, so allow a little slack beyond that off-by-one.
    t.expectEqual(
        FullscreenDetector.evaluate(
            windows: [window(appPID, CGRect(x: 0, y: 33.5, width: 1512, height: 948.5))],
            displays: [DisplayGeometry(bounds: leftRect, topInset: 32)],
            frontmostPID: appPID, ownPID: ownPID),
        FullscreenState(isFrontmost: true, coversEveryDisplay: true))

    // notched display: a window that leaves the Dock area visible is not fullscreen.
    t.expectEqual(
        FullscreenDetector.evaluate(
            windows: [window(appPID, CGRect(x: 0, y: 33, width: 1512, height: 880))],
            displays: [notched], frontmostPID: appPID, ownPID: ownPID),
        FullscreenState(isFrontmost: false, coversEveryDisplay: false))

    // right at a Space change the window list still shows the Space being left (measured
    // live). entering fullscreen is visible immediately, so accept a newly seen fullscreen.
    let none = FullscreenState(isFrontmost: false, coversEveryDisplay: false)
    let full = FullscreenState(isFrontmost: true, coversEveryDisplay: true)
    let partial = FullscreenState(isFrontmost: true, coversEveryDisplay: false)
    t.expectEqual(FullscreenDetector.afterSpaceChange(previous: none, sampled: full), full)
    t.expectEqual(FullscreenDetector.afterSpaceChange(previous: none, sampled: partial), partial)
    // leaving fullscreen still samples as fullscreen: treat that as stale and assume it ended,
    // so the wallpaper resumes at once instead of after the settle recheck.
    t.expectEqual(FullscreenDetector.afterSpaceChange(previous: full, sampled: full), none)
    t.expectEqual(FullscreenDetector.afterSpaceChange(previous: partial, sampled: partial), none)
    // a sample that already moved on is trusted as is.
    t.expectEqual(FullscreenDetector.afterSpaceChange(previous: full, sampled: none), none)
    t.expectEqual(FullscreenDetector.afterSpaceChange(previous: full, sampled: partial), partial)
    t.expectEqual(FullscreenDetector.afterSpaceChange(previous: none, sampled: none), none)
}
