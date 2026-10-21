import XCTest
@testable import MagicCharger
final class NotificationPreferencesTests: XCTestCase {
    let now = Date(timeIntervalSince1970: 2_000_000_000)
    func r(_ percent: Int, full: Bool = false) -> Reading {
        Reading(id: "fixture", name: "Simulation", symbol: "keyboard", percent: percent,
                state: full ? .unknown : .charging, sampled: now, evidence: "SIMULATED", fullChargeEvidence: full)
    }
    func testDisabledHighestDoesNotHideEnabledMilestoneAndReenableDoesNotReplay() {
        var t = Thresholds(); _ = t.consume(r(77), now: now)
        XCTAssertEqual(t.consume(r(81), now: now, enabled: [78]), [78])
        XCTAssertEqual(t.consume(r(82), now: now), [])
        var full = Thresholds(); _ = full.consume(r(77), now: now)
        XCTAssertEqual(full.consume(r(100, full: true), now: now, enabled: [80]), [80])
        XCTAssertEqual(full.consume(r(100, full: true), now: now), [])
    }
    func testDisabledEventsAreConsumedWithoutCooldownAndStartDoesNotReplay() {
        var t = Thresholds(); _ = t.consume(r(77), now: now)
        XCTAssertEqual(t.consume(r(81), now: now, enabled: []), [])
        XCTAssertEqual(t.consume(r(82), now: now), [])
        XCTAssertTrue(t.sessions["fixture"]?.lastAlert.isEmpty == true)
        var starts = ChargingStarts()
        var idle = r(65); idle = Reading(id: idle.id, name: idle.name, symbol: idle.symbol, percent: idle.percent, state: .idle, sampled: now, evidence: "SIMULATED")
        _ = starts.consume([idle], now: now)
        XCTAssertEqual(starts.consume([r(65)], now: now).count, 1) // consumed even when delivery preference is off
        XCTAssertTrue(starts.consume([r(66)], now: now).isEmpty)
    }
    func testPendingSelectionStaysCanceledAfterOffOnButOtherKindsRemainValid() {
        var settings = AlertSettings(preferences: NotificationPreferences())
        let selectedStart = settings.token(.started), selectedTarget = settings.token(.target)
        var disabled = settings.preferences; disabled.started = false
        settings.update(disabled)
        XCTAssertFalse(settings.canSubmit(.started, token: selectedStart))
        XCTAssertTrue(settings.canSubmit(.target, token: selectedTarget))
        disabled.started = true; settings.update(disabled)
        XCTAssertFalse(settings.canSubmit(.started, token: selectedStart))
        XCTAssertTrue(settings.canSubmit(.started, token: settings.token(.started)))
    }
    func testFourPreferencesPersistIndependentlyAndDefaultOn() throws {
        let suite = "MagicChargerTests." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        XCTAssertEqual(NotificationPreferences.load(defaults), NotificationPreferences())
        for bits in 0...15 {
            let p = NotificationPreferences(started: bits & 1 != 0, soon: bits & 2 != 0, target: bits & 4 != 0, full: bits & 8 != 0)
            p.save(defaults); XCTAssertEqual(NotificationPreferences.load(defaults), p)
        }
    }
}
