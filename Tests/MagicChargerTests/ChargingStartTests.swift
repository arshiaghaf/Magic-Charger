import XCTest
@testable import MagicCharger
final class ChargingStartTests: XCTestCase {
    let now = Date(timeIntervalSince1970: 2_000_000_000)
    func r(_ state: Charging, percent: Int? = 65, id: String = "mouse", age: TimeInterval = 0) -> Reading {
        Reading(id: id, name: "Simulation", symbol: "computermouse", percent: percent,
                state: state, sampled: now.addingTimeInterval(-age), evidence: "SIMULATED")
    }
    func testFreshIdleSurvivesTransientReconnectGap() {
        for transient in [[], [r(.unknown)]] {
            var tracker = ChargingStarts()
            _ = tracker.consume([r(.idle)], now: now)
            _ = tracker.consume(transient, now: now)
            XCTAssertEqual(tracker.consume([r(.charging)], now: now).count, 1)
            XCTAssertTrue(tracker.consume([r(.charging)], now: now).isEmpty)
        }
    }
    func testOnlyFreshIdleToChargingWithPercentageNotifiesOnce() {
        var tracker = ChargingStarts()
        XCTAssertTrue(tracker.consume([r(.idle)], now: now).isEmpty)
        let started = tracker.consume([r(.charging), r(.charging)], now: now)
        XCTAssertEqual(started.count, 1); XCTAssertEqual(started.first?.percent, 65)
        XCTAssertTrue(tracker.consume([r(.charging)], now: now).isEmpty)
        _ = tracker.consume([r(.idle)], now: now)
        XCTAssertEqual(tracker.consume([r(.charging)], now: now).count, 1)
    }
    func testLaunchChargingReconnectExpiredIdleAndSleepStayQuiet() {
        var tracker = ChargingStarts()
        XCTAssertTrue(tracker.consume([r(.charging)], now: now).isEmpty)
        for transient in [[], [r(.unknown)]] {
            _ = tracker.consume(transient, now: now)
            XCTAssertTrue(tracker.consume([r(.charging)], now: now).isEmpty)
        }
        _ = tracker.consume([r(.idle)], now: now)
        let later = now.addingTimeInterval(91)
        let charging = Reading(id: "mouse", name: "Simulation", symbol: "computermouse", percent: 65,
            state: .charging, sampled: later, evidence: "SIMULATED")
        XCTAssertTrue(tracker.consume([charging], now: later).isEmpty)
        _ = tracker.consume([r(.idle)], now: now); tracker.invalidate()
        XCTAssertTrue(tracker.consume([r(.charging)], now: now).isEmpty)
        tracker = ChargingStarts()
        XCTAssertTrue(tracker.consume([r(.charging)], now: now).isEmpty)
        _ = tracker.consume([r(.idle)], now: now)
        _ = tracker.consume([r(.idle, age: 91)], now: now)
        XCTAssertTrue(tracker.consume([r(.charging)], now: now).isEmpty)
    }
    func testStartAboveTargetProducesOnlyStartAndConsumesHistoricalTargets() {
        var starts = ChargingStarts(), thresholds = Thresholds()
        _ = starts.consume([r(.idle)], now: now)
        _ = thresholds.consume(r(.idle), now: now)
        XCTAssertEqual(starts.consume([r(.charging, percent: 81)], now: now).count, 1)
        XCTAssertEqual(thresholds.consume(r(.charging, percent: 81), now: now), [])
        XCTAssertEqual(thresholds.sessions["mouse"]?.sent, Set([78,80]))
    }
    func testMissingPercentageConflictAndIndependentDevices() {
        var tracker = ChargingStarts()
        _ = tracker.consume([r(.idle), r(.idle, id: "keyboard")], now: now)
        let started = tracker.consume([r(.charging, percent: nil), r(.charging, id: "keyboard")], now: now)
        XCTAssertEqual(started.map { $0.id }, ["keyboard"])
        XCTAssertTrue(tracker.consume([r(.charging, percent: 66)], now: now).isEmpty)
        _ = tracker.consume([r(.idle)], now: now)
        XCTAssertTrue(tracker.consume([r(.charging), r(.idle)], now: now).isEmpty)
    }
}
