import XCTest
@testable import TransitETAApp

final class RenderingTests: XCTestCase {
    func testNoStopConfigured() {
        XCTAssertEqual(menuBarState(pin: nil, stopName: nil, events: [], now: Date()), .noStop)
    }

    func testShowsStopNameWhenUnpinned() {
        XCTAssertEqual(menuBarState(pin: nil, stopName: "Bern", events: [], now: Date()), .unpinned(stopName: "Bern"))
    }

    func testShowsLineDestinationAndETAWhenPinned() {
        let scheduled = Date(timeIntervalSince1970: 1_000_000)
        let event = StopEvent(mode: "rail", lineName: "IC 1", destination: "Genève", scheduledTime: scheduled, estimatedTime: nil, platform: nil)
        let now = scheduled.addingTimeInterval(-4 * 60)
        let pin = Pin(mode: "rail", lineName: "IC 1", destination: "Genève")
        let state = menuBarState(pin: pin, stopName: "Bern", events: [event], now: now)
        XCTAssertEqual(state, .pinned(iconName: "train-profile", lineName: "IC 1", destination: "Genève", etaText: "4′", delayText: nil))
    }

    func testFlagsDelayWhenPinnedLineIsLate() {
        let scheduled = Date(timeIntervalSince1970: 1_000_000)
        let estimated = scheduled.addingTimeInterval(3 * 60)
        let event = StopEvent(mode: "bus", lineName: "12", destination: "Bern, Bahnhof", scheduledTime: scheduled, estimatedTime: estimated, platform: nil)
        let now = estimated.addingTimeInterval(-2 * 60)
        let pin = Pin(mode: "bus", lineName: "12", destination: "Bern, Bahnhof")
        let state = menuBarState(pin: pin, stopName: "Bern", events: [event], now: now)
        XCTAssertEqual(state, .pinned(iconName: "bus-profile", lineName: "12", destination: "Bern, Bahnhof", etaText: "2′", delayText: "+3′"))
    }

    func testFallsBackWhenPinnedLineNotInNextEvents() {
        let pin = Pin(mode: "tram", lineName: "99", destination: "Nowhere")
        let state = menuBarState(pin: pin, stopName: "Bern", events: [], now: Date())
        XCTAssertEqual(state, .notRunning(iconName: "tram-profile", lineName: "99", destination: "Nowhere"))
    }

    func testCompactEtaFormatsZeroAsNow() {
        XCTAssertEqual(compactETA(0), "now")
    }

    func testCompactEtaFormatsMinutesWithPrime() {
        XCTAssertEqual(compactETA(4), "4′")
    }
}
