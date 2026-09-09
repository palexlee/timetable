import XCTest
import Combine
@testable import TransitETAApp

@MainActor
final class AppModelTests: XCTestCase {
    private func makeConfig() -> Config {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        return Config(directory: dir, keychainService: "local.transit-eta.tests")
    }

    func testPinUpdatesConfigAndNotifiesObservers() {
        let config = makeConfig()
        config.setStop(stopRef: "8507000", stopName: "Bern")
        let model = AppModel(config: config)
        var notified = false
        let cancellable = model.objectWillChange.sink { _ in notified = true }
        let event = StopEvent(mode: "bus", lineName: "46", destination: "Rütihof", scheduledTime: Date(), estimatedTime: nil, platform: nil)

        model.pin(event)

        XCTAssertTrue(notified)
        XCTAssertEqual(config.pinned, Pin(mode: "bus", lineName: "46", destination: "Rütihof"))
        cancellable.cancel()
    }

    func testUnpinClearsConfig() {
        let config = makeConfig()
        config.setStop(stopRef: "8507000", stopName: "Bern")
        config.setPin(Pin(mode: "bus", lineName: "46", destination: "Rütihof"))
        let model = AppModel(config: config)

        model.unpin()

        XCTAssertNil(config.pinned)
    }

    func testRefreshWithNoAPIKeySetsErrorInsteadOfThrowing() async {
        let config = makeConfig()
        config.setStop(stopRef: "8507000", stopName: "Bern")
        let model = AppModel(config: config)

        await model.refresh()

        XCTAssertEqual(model.errorMessage, "No API key configured (set TRANSIT_ETA_API_KEY or use the menu).")
        XCTAssertEqual(model.events, [])
    }

    func testRefreshWithNoStopSetsErrorInsteadOfThrowing() async {
        let config = makeConfig()
        try? config.setAPIKey("test-key")
        let model = AppModel(config: config)

        await model.refresh()

        XCTAssertEqual(model.errorMessage, "No stop configured yet.")
    }
}
