import XCTest
@testable import MagicCharger
final class ChargingDecoderTests: XCTestCase {
    let os = OperatingSystemVersion(majorVersion: 27, minorVersion: 2, patchVersion: 0)
    func decode(_ flags: Int?, percent: Int? = 65, vendor: Int = 76, product: Int = 803,
                transport: String? = "Bluetooth", system: OperatingSystemVersion? = nil,
                a: Bool? = nil, b: Bool? = nil) -> Charging {
        ChargingDecoder.decode(vendor: vendor, product: product, transport: transport, os: system ?? os,
                               percent: percent, flags: flags, batteryCharging: a, isCharging: b)
    }
    func testScopedCableTransitionAndFullUncertainty() {
        for product in [803, 801] {
            XCTAssertEqual([4, 3, 4].map { decode($0, product: product) }, [.idle, .charging, .idle])
            for p in [nil, 100, 101, -1] as [Int?] { XCTAssertEqual(decode(3, percent: p, product: product), .unknown) }
            for flag in [nil, 0, 1, 2, 5, 255] as [Int?] { XCTAssertEqual(decode(flag, product: product), .unknown) }
        }
    }
    func testUnvalidatedProfilesAndContradictionsStayUnknown() {
        XCTAssertEqual(decode(3, product: 999), .unknown)
        XCTAssertEqual(decode(4, product: 999), .unknown)
        XCTAssertEqual(decode(3, vendor: 1452), .unknown)
        XCTAssertEqual(decode(3, transport: "USB"), .unknown)
        XCTAssertEqual(decode(3, a: false), .unknown)
        XCTAssertEqual(decode(4, a: true), .unknown)
        XCTAssertEqual(decode(3, a: true, b: false), .unknown)
    }
    func testRecognizedFlagsBehaveConsistentlyAcrossOSVersions() {
        let versions = [
            OperatingSystemVersion(majorVersion: 14, minorVersion: 0, patchVersion: 0),
            OperatingSystemVersion(majorVersion: 27, minorVersion: 2, patchVersion: 1),
            OperatingSystemVersion(majorVersion: 27, minorVersion: 3, patchVersion: 0),
            OperatingSystemVersion(majorVersion: 28, minorVersion: 0, patchVersion: 0)
        ]
        for system in versions {
            for product in [803, 801] {
                XCTAssertEqual(decode(3, product: product, system: system), .charging)
                XCTAssertEqual(decode(4, product: product, system: system), .idle)
                XCTAssertEqual(decode(2, product: product, system: system), .unknown)
                XCTAssertEqual(decode(3, percent: 100, product: product, system: system), .unknown)
                XCTAssertEqual(decode(3, product: product, system: system, a: false), .unknown)
                XCTAssertEqual(decode(4, product: product, system: system, b: true), .unknown)
                XCTAssertEqual(decode(3, product: product, system: system, a: true, b: false), .unknown)
            }
        }
    }
    func testDuplicateConflictAndFreshMenuEligibility() {
        let now = Date()
        func r(_ state: Charging, percent: Int? = 65, id: String = "a", date: Date? = nil) -> Reading {
            Reading(id: id, name: "Simulation", symbol: "computermouse", percent: percent, state: state,
                    sampled: date ?? now, evidence: "SIMULATED")
        }
        XCTAssertTrue(r(decode(3)).active)
        XCTAssertFalse(r(decode(4)).active)
        XCTAssertFalse(r(.charging, date: now.addingTimeInterval(-91)).active)
        XCTAssertEqual(reconciled([r(.charging), r(.idle)]).first?.state, .unknown)
        XCTAssertEqual(reconciled([r(.charging), r(.charging, percent: 66)]).first?.state, .unknown)
        XCTAssertEqual(reconciled([r(.charging), r(.charging)]).count, 1)
        XCTAssertEqual(reconciled([r(.charging), r(.idle, id: "b")]).count, 2)
    }
}
