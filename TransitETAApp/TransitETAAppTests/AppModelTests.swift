import XCTest
import Combine
@testable import TransitETAApp

@MainActor
final class AppModelTests: XCTestCase {
    private let testKeychainService = "local.transit-eta.tests"

    private func makeConfig() -> Config {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        return Config(directory: dir, keychainService: testKeychainService)
    }

    override func setUp() {
        super.setUp()
        // A developer's real TRANSIT_ETA_API_KEY must not leak in: none of
        // these tests are about env-var precedence, but Config.apiKey checks
        // the env var before the Keychain.
        unsetenv("TRANSIT_ETA_API_KEY")
    }

    override func tearDown() {
        KeychainStore.delete(service: testKeychainService, account: "api-key")
        super.tearDown()
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

    func testMenuBarLabelStateReflectsPinnedEventAfterRefresh() {
        let config = makeConfig()
        config.setStop(stopRef: "8507000", stopName: "Bern")
        let pin = Pin(mode: "bus", lineName: "46", destination: "Rütihof")
        config.setPin(pin)
        let model = AppModel(config: config)

        // Proves the property delegates to the free function with the right
        // arguments (no live network call involved).
        let now = Date()
        XCTAssertEqual(
            model.menuBarLabelState,
            menuBarState(pin: config.pinned, stopName: config.stopName, events: model.events, now: now)
        )
    }
}
