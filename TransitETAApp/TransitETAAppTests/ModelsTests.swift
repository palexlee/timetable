import XCTest
@testable import TransitETAApp

final class ModelsTests: XCTestCase {
    private func makeEvent(mode: String = "bus", line: String = "46", destination: String, scheduled: Date = Date(timeIntervalSince1970: 0), estimated: Date? = nil) -> StopEvent {
        StopEvent(mode: mode, lineName: line, destination: destination, scheduledTime: scheduled, estimatedTime: estimated, platform: nil)
    }

    func testMatchesPinDespiteNFCNFDMismatch() {
        // macOS hands back accented text from a click's args as NFD
        // ("u" + combining diaeresis); the OJP API sends NFC (precomposed
        // "ü"). Same text, different codepoints -- matchesPin must not care.
        let nfc = "Rütihof" // Swift normalizes literals to NFC
        let nfd = nfc.decomposedStringWithCanonicalMapping // Force NFD
        // Swift's String == normalizes both sides, so check at the NSString level
        XCTAssertNotEqual((nfc as NSString).length, (nfd as NSString).length, "sanity: they really are different strings")

        let event = makeEvent(destination: nfc)
        let pin = Pin(mode: "bus", lineName: "46", destination: nfd)
        XCTAssertTrue(event.matchesPin(pin))
    }

    func testDoesNotMatchDifferentLineOrDestination() {
        let event = makeEvent(destination: "Rütihof")
        XCTAssertFalse(event.matchesPin(Pin(mode: "bus", lineName: "99", destination: "Rütihof")))
        XCTAssertFalse(event.matchesPin(Pin(mode: "bus", lineName: "46", destination: "Elsewhere")))
        XCTAssertFalse(event.matchesPin(nil))
    }

    func testDelayMinutesComputedFromEstimatedMinusScheduled() {
        let scheduled = Date(timeIntervalSince1970: 0)
        let estimated = scheduled.addingTimeInterval(180)
        let event = makeEvent(destination: "X", scheduled: scheduled, estimated: estimated)
        XCTAssertTrue(event.isDelayed)
        XCTAssertEqual(event.delayMinutes, 3)
    }

    func testNotDelayedWhenEstimatedEqualsScheduled() {
        let time = Date(timeIntervalSince1970: 0)
        let event = makeEvent(destination: "X", scheduled: time, estimated: time)
        XCTAssertFalse(event.isDelayed)
        XCTAssertEqual(event.delayMinutes, 0)
    }

    func testEtaMinutesRoundsAndNeverGoesNegative() {
        let scheduled = Date(timeIntervalSince1970: 1000)
        let event = makeEvent(destination: "X", scheduled: scheduled)
        XCTAssertEqual(event.etaMinutes(now: Date(timeIntervalSince1970: 1000 - 240)), 4)
        XCTAssertEqual(event.etaMinutes(now: Date(timeIntervalSince1970: 1000 + 60)), 0)
    }

    func testIconAssetNameMapsEveryOJPMode() {
        XCTAssertEqual(iconAssetName(forMode: "rail"), "train-profile")
        XCTAssertEqual(iconAssetName(forMode: "suburbanrail"), "train-profile")
        XCTAssertEqual(iconAssetName(forMode: "tram"), "tram-profile")
        XCTAssertEqual(iconAssetName(forMode: "bus"), "bus-profile")
        XCTAssertEqual(iconAssetName(forMode: "coach"), "bus-profile")
        XCTAssertEqual(iconAssetName(forMode: "metro"), "underground-vehicule-profile")
        XCTAssertEqual(iconAssetName(forMode: "underground"), "underground-vehicule-profile")
        XCTAssertEqual(iconAssetName(forMode: "water"), "boat-profile")
        XCTAssertEqual(iconAssetName(forMode: "cableway"), "cable-car-profile")
        XCTAssertEqual(iconAssetName(forMode: "funicular"), "funicular-profile")
        XCTAssertEqual(iconAssetName(forMode: "something-else"), "station")
        XCTAssertEqual(iconAssetName(forMode: "RAIL"), "train-profile", "case-insensitive")
    }

    func testPinJSONKeysUseSnakeCase() throws {
        let pin = Pin(mode: "bus", lineName: "46", destination: "Rütihof")
        let data = try JSONEncoder().encode(pin)
        let json = try XCTUnwrap(String(data: data, encoding: .utf8))
        XCTAssertTrue(json.contains("\"line_name\""))
        XCTAssertFalse(json.contains("\"lineName\""))
    }
}
