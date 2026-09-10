import XCTest
@testable import TransitETAApp

final class DesignTokensTests: XCTestCase {
    func testLineBadgeColorByLineNamePrefix() {
        XCTAssertEqual(lineBadgeColor(iconName: "train-profile", lineName: "IC81"), lineBadgeColor(iconName: "train-profile", lineName: "IC 1"))
        XCTAssertEqual(lineBadgeColor(iconName: "train-profile", lineName: "EC1"), lineBadgeColor(iconName: "train-profile", lineName: "IC81"), "EC shares the IC/EC red family")
        XCTAssertNotEqual(lineBadgeColor(iconName: "train-profile", lineName: "IR15"), lineBadgeColor(iconName: "train-profile", lineName: "IC81"))
        XCTAssertNotEqual(lineBadgeColor(iconName: "train-profile", lineName: "RE"), lineBadgeColor(iconName: "train-profile", lineName: "IR15"))
        XCTAssertEqual(lineBadgeColor(iconName: "train-profile", lineName: "S3"), lineBadgeColor(iconName: "train-profile", lineName: "S11"), "all S-Bahn lines share one blue")
    }

    func testLineBadgeColorFallsBackToIconNameWhenNoPrefixMatches() {
        XCTAssertEqual(lineBadgeColor(iconName: "bus-profile", lineName: "46"), lineBadgeColor(iconName: "bus-profile", lineName: "12"))
        XCTAssertNotEqual(lineBadgeColor(iconName: "bus-profile", lineName: "46"), lineBadgeColor(iconName: "tram-profile", lineName: "9"))
    }

    func testLineBadgeColorIsCaseInsensitiveOnPrefix() {
        XCTAssertEqual(lineBadgeColor(iconName: "train-profile", lineName: "ic81"), lineBadgeColor(iconName: "train-profile", lineName: "IC81"))
    }
}
