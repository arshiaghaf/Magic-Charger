import XCTest
import AppKit
@testable import MagicCharger
@MainActor
final class ControlsWindowTests: XCTestCase {
    func testFourAlertLayoutBuildsWithoutPrematureCrossHierarchyConstraints() throws {
        let application = NSApplication.shared
        let controller = ControlsWindow(target: application, enable: #selector(NSApplication.terminate(_:)),
            test: #selector(NSApplication.terminate(_:)), quit: #selector(NSApplication.terminate(_:)),
            preferences: MenuBarPreferences(), alerts: NotificationPreferences(), onChange: { _ in }, onAlertsChange: { _ in })
        controller.update(readings: [], notificationStatus: "Notifications enabled.", feedback: "", diagnostic: "SIMULATED")
        let window = try XCTUnwrap(controller.window)
        window.contentView?.layoutSubtreeIfNeeded()
        XCTAssertEqual(window.contentLayoutRect.width, 440)
        XCTAssertFalse(window.isVisible)
        window.close()
    }
}
