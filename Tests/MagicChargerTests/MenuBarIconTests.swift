import XCTest
import AppKit
@testable import MagicCharger
final class MenuBarIconTests: XCTestCase {
    func alpha(_ percent: Int?, symbol: String = "keyboard") throws -> Double {
        let image = MenuBarIcon.image(symbol: symbol, percent: percent)
        XCTAssertTrue(image.isTemplate)
        XCTAssertEqual(image.size, NSSize(width: 30, height: 18))
        let rep = try XCTUnwrap(NSBitmapImageRep(data: try XCTUnwrap(image.tiffRepresentation)))
        return (0..<rep.pixelsWide).reduce(0) { sum, x in
            sum + (0..<rep.pixelsHigh).reduce(0) { $0 + (rep.colorAt(x: x, y: $1)?.alphaComponent ?? 0) }
        }
    }
    func testFillIncreasesWithActualPercentageAndUnknownIsDistinct() throws {
        for symbol in ["keyboard", "computermouse"] {
            let empty = try alpha(0, symbol: symbol), half = try alpha(50, symbol: symbol), full = try alpha(100, symbol: symbol)
            XCTAssertLessThan(empty, half); XCTAssertLessThan(half, full)
        }
        let empty = try alpha(0)
        XCTAssertNotEqual(try alpha(nil), empty)
        XCTAssertEqual(try alpha(-1), try alpha(nil))
        XCTAssertEqual(try alpha(101), try alpha(nil))
    }
}
