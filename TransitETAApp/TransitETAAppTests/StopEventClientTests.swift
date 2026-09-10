import XCTest
@testable import TransitETAApp

final class StopEventClientTests: XCTestCase {
    private func loadFixture(_ name: String) throws -> Data {
        guard let url = Bundle(for: Self.self).url(forResource: name, withExtension: "xml", subdirectory: "Fixtures")
            ?? Bundle(for: Self.self).url(forResource: name, withExtension: "xml") else {
            throw XCTSkip("Fixture \(name).xml not found in test bundle.")
        }
        return try Data(contentsOf: url)
    }

    func testParsesEventsSortedByTimeIncludingPublicCodeFallback() throws {
        let events = try parseStopEventResponse(try loadFixture("stop_event_response"))
        XCTAssertEqual(events.map { $0.lineName }, ["IC 1", "12", "9", "IR"])
    }

    func testFallsBackToPublicCodeWhenNoPublishedLineName() throws {
        // Real OJP responses send PublicCode instead of PublishedLineName --
        // verified against the live API. See the Python fix this ports:
        // swiftbar_plugin/transit_eta/ojp_client.py's line_name fallback.
        let events = try parseStopEventResponse(try loadFixture("stop_event_response"))
        let ir = try XCTUnwrap(events.last)
        XCTAssertEqual(ir.lineName, "IR")
        XCTAssertEqual(ir.destination, "Zürich Flughafen")
    }

    func testParsesModeDestinationAndPlatform() throws {
        let events = try parseStopEventResponse(try loadFixture("stop_event_response"))
        let ic1 = events[0]
        XCTAssertEqual(ic1.mode, "rail")
        XCTAssertEqual(ic1.destination, "Genève")
        XCTAssertEqual(ic1.platform, "3")
    }

    func testDetectsDelay() throws {
        let events = try parseStopEventResponse(try loadFixture("stop_event_response"))
        let bus12 = try XCTUnwrap(events.first { $0.lineName == "12" })
        XCTAssertTrue(bus12.isDelayed)
        XCTAssertEqual(bus12.delayMinutes, 3)
    }

    func testNoDelayWhenEstimatedEqualsScheduled() throws {
        let events = try parseStopEventResponse(try loadFixture("stop_event_response"))
        XCTAssertFalse(events[0].isDelayed)
    }

    func testFallsBackToScheduledTimeWhenNoEstimate() throws {
        let events = try parseStopEventResponse(try loadFixture("stop_event_response"))
        let tram9 = try XCTUnwrap(events.first { $0.lineName == "9" })
        XCTAssertNil(tram9.estimatedTime)
        XCTAssertEqual(tram9.bestTime, tram9.scheduledTime)
    }

    func testBuildStopEventRequestUsesStopPlaceRefNotStopPointRef() {
        // location_client's search returns StopPlace refs (e.g.
        // "ch:1:sloid:7000"). Wrapping that in <StopPointRef> instead of
        // <StopPlaceRef> made the live OJP backend 500 -- confirmed against
        // the real API. This must never regress.
        let xml = String(data: buildStopEventRequest(stopRef: "ch:1:sloid:7000", numberOfResults: 5), encoding: .utf8)!
        XCTAssertTrue(xml.contains("<StopPlaceRef>ch:1:sloid:7000</StopPlaceRef>"))
        XCTAssertFalse(xml.contains("StopPointRef"))
    }

    func testNonXMLBodyThrowsOjpErrorNotAParseError() {
        XCTAssertThrowsError(try parseStopEventResponse("Service Unavailable".data(using: .utf8)!)) { error in
            XCTAssertTrue(error is OjpError)
        }
    }
}
