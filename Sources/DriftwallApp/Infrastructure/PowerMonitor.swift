import Foundation
import IOKit.ps

// reports whether the mac is running on battery and notifies when the power source changes.
// desktops with no battery always report false (on AC).
@MainActor
final class PowerMonitor {
    // invoked on the main thread whenever the power source changes.
    var onChange: (@MainActor () -> Void)?

    private var runLoopSource: CFRunLoopSource?

    var isOnBattery: Bool {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef]
        else {
            return false
        }
        for source in sources {
            guard let description = IOPSGetPowerSourceDescription(snapshot, source)?
                .takeUnretainedValue() as? [String: Any],
                let state = description[kIOPSPowerSourceStateKey] as? String
            else {
                continue
            }
            if state == kIOPSBatteryPowerValue {
                return true
            }
        }
        return false
    }

    func start() {
        // the callback is a C function pointer, so route change events back to this instance
        // through an unretained context pointer. the source runs on the main run loop.
        let context = Unmanaged.passUnretained(self).toOpaque()
        guard let source = IOPSNotificationCreateRunLoopSource({ rawContext in
            guard let rawContext else { return }
            let monitor = Unmanaged<PowerMonitor>.fromOpaque(rawContext).takeUnretainedValue()
            MainActor.assumeIsolated { monitor.onChange?() }
        }, context)?.takeRetainedValue() else {
            return
        }
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
    }

    func stop() {
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .defaultMode)
            runLoopSource = nil
        }
    }
}
