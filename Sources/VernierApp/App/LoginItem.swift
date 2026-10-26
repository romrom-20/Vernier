import AppKit
import ServiceManagement

enum LoginItemState: Equatable {
    case off, enabled, needsApproval, unavailable
    var label: String {
        switch self {
        case .off: "Start manually"
        case .enabled: "Opens at login"
        case .needsApproval: "Needs macOS approval"
        case .unavailable: "Login service unavailable"
        }
    }
}

extension AppModel {
    func refreshLoginStatus() {
        guard !isolatedEnvironment else { return }
        switch SMAppService.mainApp.status {
        case .notRegistered: loginStatus = .off
        case .enabled: loginStatus = .enabled
        case .requiresApproval: loginStatus = .needsApproval
        case .notFound: loginStatus = .unavailable
        @unknown default: loginStatus = .unavailable
        }
    }
    func setLaunchAtLogin(_ enabled: Bool) {
        guard !isolatedEnvironment else { return }
        loginError = nil
        do {
            let service = SMAppService.mainApp
            if enabled {
                if service.status != .enabled && service.status != .requiresApproval { try service.register() }
            } else if service.status == .enabled || service.status == .requiresApproval { try service.unregister() }
        } catch {
            let code = (error as NSError).code
            loginError = "macOS couldn’t change this login item (code \(code)). Check Login Items in System Settings. This local development build may need a signed release."
        }
        refreshLoginStatus()
    }
    func openLoginSettings() { SMAppService.openSystemSettingsLoginItems() }
}
