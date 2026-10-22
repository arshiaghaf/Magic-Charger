import XCTest
@testable import MagicCharger

final class NotificationCopyTests: XCTestCase {
    func testStartedAndMilestoneCopy() {
        let started = NotificationCopy.started(name: "Magic Keyboard", percent: 42)
        XCTAssertEqual(started.title, "Magic Keyboard started charging")
        XCTAssertEqual(started.body, "Currently at 42%")

        let soon = NotificationCopy.milestone(name: "Magic Keyboard", percent: 79, threshold: 78)
        XCTAssertEqual(soon.title, "Magic Keyboard reached 78%")
        XCTAssertEqual(soon.body, "Get ready to unplug soon.")

        let target = NotificationCopy.milestone(name: "Magic Keyboard", percent: 82, threshold: 80)
        XCTAssertEqual(target.title, "Magic Keyboard reached 80%")
        XCTAssertEqual(target.body, "Unplug to preserve battery life.")
    }

    func testFullChargeCopyReassuresBothDevices() {
        let keyboard = NotificationCopy.milestone(name: "Magic Keyboard", percent: 100, threshold: 100)
        XCTAssertEqual(keyboard.title, "Magic Keyboard is fully charged")
        XCTAssertEqual(keyboard.body, "You can leave it plugged in. There’s no need to unplug right away.")

        let mouse = NotificationCopy.milestone(name: "Magic Mouse", percent: 100, threshold: 100)
        XCTAssertEqual(mouse.title, "Magic Mouse is fully charged")
        XCTAssertEqual(mouse.body, keyboard.body)
    }
}
