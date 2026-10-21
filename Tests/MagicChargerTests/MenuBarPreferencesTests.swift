import XCTest
@testable import MagicCharger
final class MenuBarPreferencesTests: XCTestCase {
    func testBucketsNeverOverstateFullAndNumbersNeedNoRounding() {
        for percent in 0...100 {
            let bucket = MenuBarPreferences.level(percent)!
            XCTAssertEqual(bucket % 10, 0)
            XCTAssertLessThanOrEqual(bucket, percent)
            if percent < 100 { XCTAssertLessThan(bucket, 100) }
        }
        XCTAssertEqual(MenuBarPreferences.level(99), 90)
        XCTAssertEqual(MenuBarPreferences.level(100), 100)
        XCTAssertNil(MenuBarPreferences.level(nil))
    }
    func testIndependentPersistentCombinationsAndInvalidRecovery() throws {
        let suite = "MagicChargerTests." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        XCTAssertEqual(MenuBarPreferences.load(defaults), MenuBarPreferences())
        for bits in 1...7 {
            let preference = MenuBarPreferences(deviceGlyph: bits & 1 != 0, percentage: bits & 2 != 0, batteryBar: bits & 4 != 0)
            preference.save(defaults)
            XCTAssertEqual(MenuBarPreferences.load(defaults), preference)
        }
        defaults.set(false, forKey: "menu.deviceGlyph"); defaults.set(false, forKey: "menu.percentage"); defaults.set(false, forKey: "menu.batteryBar")
        XCTAssertEqual(MenuBarPreferences.load(defaults), MenuBarPreferences())
    }
}
