import XCTest
@testable import MagicCharger
final class FullChargeTests: XCTestCase {
    let now = Date(timeIntervalSince1970: 2_000_000_000)
    func r(_ p: Int, state: Charging = .charging, evidence: Bool = false) -> Reading {
        Reading(id: "simulation", name: "Simulation", symbol: "keyboard", percent: p, state: state,
                sampled: now, evidence: "SIMULATED", fullChargeEvidence: evidence)
    }
    func testJumpSelectsOnlyFullAndPersistsConsumption() throws {
        var t = Thresholds(); _ = t.consume(r(77), now: now)
        XCTAssertEqual(t.consume(r(100, state: .unknown, evidence: true), now: now), [100])
        XCTAssertEqual(t.sessions["simulation"]?.sent, Set([78,80,100]))
        var restart = Thresholds()
        restart.sessions = try JSONDecoder().decode([String: Session].self, from: JSONEncoder().encode(t.sessions))
        XCTAssertEqual(restart.consume(r(100, state: .unknown, evidence: true), now: now), [])
    }
    func testRestartAtFullFromPersistedBelowFullDoesNotReplayCompletion() throws {
        var old = Thresholds(); _ = old.consume(r(99), now: now)
        var restarted = Thresholds()
        restarted.sessions = try JSONDecoder().decode([String: Session].self, from: JSONEncoder().encode(old.sessions))
        XCTAssertEqual(restarted.consume(r(100, state: .unknown, evidence: true), now: now), [])
        let stale = Reading(id: "simulation", name: "Simulation", symbol: "keyboard", percent: 100,
            state: .unknown, sampled: now.addingTimeInterval(-100), evidence: "SIMULATED", fullChargeEvidence: true)
        XCTAssertEqual(old.consume(stale, now: now), [])
    }
    func testFullRequiresProcessContinuityAndRecognizedEvidence() {
        var t = Thresholds(); _ = t.consume(r(99), now: now)
        XCTAssertEqual(t.consume(r(100, state: .unknown), now: now), [])
        XCTAssertEqual(t.consume(r(100, state: .unknown, evidence: true), now: now), [])
        var restart = Thresholds(); _ = restart.consume(r(100, state: .unknown, evidence: true), now: now)
        XCTAssertTrue(restart.sessions["simulation"]?.sent.contains(100) == true)
        _ = t.consume(r(99), now: now); t.invalidateContinuity()
        XCTAssertEqual(t.consume(r(100, state: .unknown, evidence: true), now: now), [])
        _ = t.consume(r(99), now: now); t.retainContinuity(for: [])
        XCTAssertEqual(t.consume(r(100, state: .unknown, evidence: true), now: now), [])
    }
    func testFullEvidenceDoesNotAssertActiveCurrentOrAcceptConflict() {
        let os = OperatingSystemVersion(majorVersion: 27, minorVersion: 2, patchVersion: 0)
        for product in [801,803] {
            XCTAssertEqual(ChargingDecoder.decode(vendor: 76, product: product, transport: "Bluetooth", os: os,
                percent: 100, flags: 3, batteryCharging: nil, isCharging: nil), .unknown)
            XCTAssertTrue(ChargingDecoder.fullChargeEvidence(vendor: 76, product: product, transport: "Bluetooth", os: os,
                percent: 100, flags: 3, batteryCharging: nil, isCharging: nil))
            XCTAssertFalse(ChargingDecoder.fullChargeEvidence(vendor: 76, product: product, transport: "Bluetooth", os: os,
                percent: 100, flags: 3, batteryCharging: false, isCharging: nil))
        }
    }
}
