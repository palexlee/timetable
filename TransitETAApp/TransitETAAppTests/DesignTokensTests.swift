import XCTest
@testable import TransitETAApp

final class DesignTokensTests: XCTestCase {
    func testLineBadgeColorByLineNamePrefix() {
        XCTAssertEqual(lineBadgeColor(mode: "rail", lineName: "IC81"), lineBadgeColor(mode: "rail", lineName: "IC 1"))
        XCTAssertEqual(lineBadgeColor(mode: "rail", lineName: "EC1"), lineBadgeColor(mode: "rail", lineName: "IC81"), "EC shares the IC/EC red family")
        XCTAssertNotEqual(lineBadgeColor(mode: "rail", lineName: "IR15"), lineBadgeColor(mode: "rail", lineName: "IC81"))
        XCTAssertNotEqual(lineBadgeColor(mode: "rail", lineName: "RE"), lineBadgeColor(mode: "rail", lineName: "IR15"))
        XCTAssertEqual(lineBadgeColor(mode: "rail", lineName: "S3"), lineBadgeColor(mode: "rail", lineName: "S11"), "all S-Bahn lines share one blue")
    }

    func testLineBadgeColorFallsBackToModeWhenNoPrefixMatches() {
        XCTAssertEqual(lineBadgeColor(mode: "bus", lineName: "46"), lineBadgeColor(mode: "bus", lineName: "12"))
        XCTAssertNotEqual(lineBadgeColor(mode: "bus", lineName: "46"), lineBadgeColor(mode: "tram", lineName: "9"))
    }

    func testLineBadgeColorIsCaseInsensitiveOnPrefix() {
        XCTAssertEqual(lineBadgeColor(mode: "rail", lineName: "ic81"), lineBadgeColor(mode: "rail", lineName: "IC81"))
    }
}
