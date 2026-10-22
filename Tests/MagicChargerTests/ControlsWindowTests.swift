import XCTest
import AppKit
import CoreServices
import ServiceManagement
@testable import MagicCharger
@MainActor
final class ControlsWindowTests: XCTestCase {
    func testLoginOpenEventIsQuietButOrdinaryLaunchAndReopenAreNot() {
        XCTAssertTrue(AppLaunch.isLoginItem(eventID: kAEOpenApplication, launchData: keyAELaunchedAsLogInItem))
        XCTAssertFalse(AppLaunch.isLoginItem(eventID: kAEOpenApplication, launchData: nil))
        XCTAssertFalse(AppLaunch.isLoginItem(eventID: kAEReopenApplication, launchData: keyAELaunchedAsLogInItem))
    }

    func testWindowHeightLeavesRoomForChromeAndScrolling() {
        XCTAssertEqual(ControlsWindow.boundedContentHeight(requested: 800, visible: 600, chrome: 30), 530)
        XCTAssertEqual(ControlsWindow.boundedContentHeight(requested: 500, visible: 800, chrome: 30), 500)
    }

    func testLoginApprovalHasDistinctPresentationState() {
        let pending = LoginItemViewState(.requiresApproval)
        XCTAssertEqual(pending.toggle, .mixed)
        XCTAssertFalse(pending.canToggle)
        XCTAssertTrue(pending.needsApproval)
        let enabled = LoginItemViewState(.enabled)
        XCTAssertEqual(enabled.toggle, .on)
        XCTAssertTrue(enabled.canToggle)
        XCTAssertFalse(enabled.needsApproval)
        XCTAssertEqual(LoginItemViewState(.notRegistered).toggle, .off)
        let notFound = LoginItemViewState(.notFound)
        XCTAssertEqual(notFound.toggle, .off)
        XCTAssertTrue(notFound.canToggle)
        XCTAssertFalse(notFound.needsApproval)
    }

    func testFourAlertLayoutBuildsWithoutPrematureCrossHierarchyConstraints() throws {
        let application = NSApplication.shared
        let controller = ControlsWindow(target: application, enable: #selector(NSApplication.terminate(_:)),
            test: #selector(NSApplication.terminate(_:)), updates: #selector(NSApplication.terminate(_:)),
            loginSettings: #selector(NSApplication.terminate(_:)), quit: #selector(NSApplication.terminate(_:)),
            preferences: MenuBarPreferences(), alerts: NotificationPreferences(),
            onChange: { _ in }, onAlertsChange: { _ in }, onLoginChange: { _ in })
        controller.update(readings: [], notificationStatus: "Notifications enabled.", feedback: "", diagnostic: "SIMULATED")
        let window = try XCTUnwrap(controller.window)
        window.contentView?.layoutSubtreeIfNeeded()
        XCTAssertEqual(window.contentLayoutRect.width, 440)
        XCTAssertFalse(window.isVisible)
        window.close()
    }
}
