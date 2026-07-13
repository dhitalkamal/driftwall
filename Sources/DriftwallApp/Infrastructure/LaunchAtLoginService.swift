import Foundation
import ServiceManagement

// registers or unregisters the app as a login item using SMAppService (macOS 13+). the
// system persists this state, so it is the source of truth for the menu checkbox.
@MainActor
enum LaunchAtLoginService {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            FileHandle.standardError.write(
                Data("Driftwall: failed to set launch at login: \(error)\n".utf8)
            )
        }
    }
}
