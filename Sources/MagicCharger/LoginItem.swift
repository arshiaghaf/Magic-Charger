import AppKit
import CoreServices
import ServiceManagement

enum AppLaunch {
    static func isLoginItem(eventID: AEEventID?, launchData: AEKeyword?) -> Bool {
        eventID == kAEOpenApplication && launchData == keyAELaunchedAsLogInItem
    }
}

extension AppDelegate {
    func changeLaunchAtLogin(_ enabled: Bool) {
        // Registration changes the user's login items only after an explicit control action.
        do {
            if enabled { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
            controls.updateLogin(status: SMAppService.mainApp.status)
        } catch {
            controls.updateLogin(status: SMAppService.mainApp.status,
                feedback: "Couldn’t change Login Items. Check System Settings > General > Login Items.")
        }
    }
    @objc func openLoginItemsSettings() { SMAppService.openSystemSettingsLoginItems() }
}
