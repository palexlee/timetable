import XCTest
@testable import TransitETAApp

final class LocationClientTests: XCTestCase {
    private func loadFixture(_ name: String) throws -> Data {
        guard let url = Bundle(for: Self.self).url(forResource: name, withExtension: "xml", subdirectory: "Fixtures")
            ?? Bundle(for: Self.self).url(forResource: name, withExtension: "xml") else {
            throw XCTSkip("Fixture \(name).xml not found in test bundle -- check it's added as a resource on the TransitETAAppTests target.")
        }
        return try Data(contentsOf: url)
    }

    func testParsesMatchesSortedByProbability() throws {
        let data = try loadFixture("location_response")
        let matches = try parseLocationResponse(data)
        XCTAssertEqual(matches.map { $0.name }, ["Bern", "Bern, Bahnhof"])
        XCTAssertEqual(matches.first?.stopRef, "8507000")
        XCTAssertEqual(matches.first?.probability, 0.98)
    }

    func testBuildLocationRequestEscapesQueryAndSetsNumberOfResults() {
        let xml = String(data: buildLocationRequest(query: "St. Gallen & Co", numberOfResults: 3), encoding: .utf8)!
        XCTAssertTrue(xml.contains("St. Gallen &amp; Co"))
        XCTAssertTrue(xml.contains("<NumberOfResults>3</NumberOfResults>"))
    }
}
