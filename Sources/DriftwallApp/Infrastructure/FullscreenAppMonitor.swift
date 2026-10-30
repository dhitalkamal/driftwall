import AppKit
import CoreGraphics
import DriftwallCore

// watches for a fullscreen app coming to the front. samples the window server on app
// activation and Space changes, then hands the window list to FullscreenDetector. only bounds,
// layer and owner pid are read (no titles), so no Screen Recording permission is needed. Space
// changes are not observed here: the app delegate calls spaceDidChange() so the state is
// settled before it re-decides playback for the new Space.
@MainActor
final class FullscreenAppMonitor {
    private(set) var state = FullscreenState(isFrontmost: false, coversEveryDisplay: false)
    // invoked (on the main thread) when the detected state changes.
    var onChange: (@MainActor () -> Void)?

    private var observers: [NSObjectProtocol] = []
    private var settleWork: DispatchWorkItem?
    private let ownPID = ProcessInfo.processInfo.processIdentifier

    func start() {
        let center = NSWorkspace.shared.notificationCenter
        let names: [Notification.Name] = [
            NSWorkspace.didActivateApplicationNotification,
            NSWorkspace.didTerminateApplicationNotification,
        ]
        for name in names {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { _ in
                MainActor.assumeIsolated { self.recheckSoon() }
            })
        }
        observers.append(NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { _ in
            MainActor.assumeIsolated { self.recheckSoon() }
        })
        recheck()
    }

    func stop() {
        settleWork?.cancel()
        let center = NSWorkspace.shared.notificationCenter
        for observer in observers {
            center.removeObserver(observer)
            NotificationCenter.default.removeObserver(observer)
        }
        observers.removeAll()
    }

    // the active Space changed. the window list still shows the Space being left at this
    // point, so resolve the sample with FullscreenDetector.afterSpaceChange, then re-sample once
    // the transition has settled.
    func spaceDidChange() {
        apply(FullscreenDetector.afterSpaceChange(previous: state, sampled: sample()))
        scheduleSettledRecheck()
    }

    // check now, then again once the fullscreen Space animation has settled.
    private func recheckSoon() {
        recheck()
        scheduleSettledRecheck()
    }

    private func recheck() {
        apply(sample())
    }

    private func scheduleSettledRecheck() {
        settleWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated { self?.recheck() }
        }
        settleWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: work)
    }

    private func sample() -> FullscreenState {
        FullscreenDetector.evaluate(
            windows: Self.onScreenWindows(),
            displays: Self.displayGeometry(),
            frontmostPID: NSWorkspace.shared.frontmostApplication?.processIdentifier,
            ownPID: ownPID
        )
    }

    private func apply(_ next: FullscreenState) {
        guard next != state else { return }
        state = next
        Diagnostics.log("fullscreen frontmost=\(next.isFrontmost) everyDisplay=\(next.coversEveryDisplay)")
        onChange?()
    }

    private static func onScreenWindows() -> [WindowSnapshot] {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let info = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return []
        }
        return info.compactMap { entry in
            guard let pid = entry[kCGWindowOwnerPID as String] as? Int32,
                  let layer = entry[kCGWindowLayer as String] as? Int,
                  let boundsDict = entry[kCGWindowBounds as String] as? NSDictionary,
                  let bounds = CGRect(dictionaryRepresentation: boundsDict as CFDictionary)
            else { return nil }
            return WindowSnapshot(ownerPID: pid, layer: layer, bounds: bounds)
        }
    }

    // CGDisplayBounds is already in global window coordinates (top-left origin of the main
    // display), matching kCGWindowBounds, so no flipping is needed. safeAreaInsets.top is the
    // notch strip height on notched panels and 0 elsewhere.
    private static func displayGeometry() -> [DisplayGeometry] {
        NSScreen.screens.compactMap { screen in
            let key = NSDeviceDescriptionKey("NSScreenNumber")
            guard let number = screen.deviceDescription[key] as? NSNumber else { return nil }
            return DisplayGeometry(
                bounds: CGDisplayBounds(CGDirectDisplayID(number.uint32Value)),
                topInset: screen.safeAreaInsets.top
            )
        }
    }
}
