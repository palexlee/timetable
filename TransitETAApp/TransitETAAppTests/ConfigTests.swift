import XCTest
@testable import TransitETAApp

final class ConfigTests: XCTestCase {
    private var tempDir: URL!
    private let testKeychainService = "local.transit-eta.tests"

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        KeychainStore.delete(service: testKeychainService, account: "api-key")
        super.tearDown()
    }

    func testSetStopPersistsAndClearsAnyExistingPin() {
        let config = Config(directory: tempDir, keychainService: testKeychainService)
        config.setPin(Pin(mode: "bus", lineName: "46", destination: "Rütihof"))
        config.setStop(stopRef: "8507000", stopName: "Bern")

        let reloaded = Config(directory: tempDir, keychainService: testKeychainService)
        XCTAssertEqual(reloaded.stopRef, "8507000")
        XCTAssertEqual(reloaded.stopName, "Bern")
        XCTAssertNil(reloaded.pinned)
    }

    func testSetPinAndClearPinRoundTrip() {
        let config = Config(directory: tempDir, keychainService: testKeychainService)
        let pin = Pin(mode: "rail", lineName: "IC81", destination: "Romanshorn")
        config.setPin(pin)
        XCTAssertEqual(Config(directory: tempDir, keychainService: testKeychainService).pinned, pin)

        config.clearPin()
        XCTAssertNil(Config(directory: tempDir, keychainService: testKeychainService).pinned)
    }

    func testConfigJSONUsesSnakeCaseKeys() throws {
        let config = Config(directory: tempDir, keychainService: testKeychainService)
        config.setStop(stopRef: "8507000", stopName: "Bern")
        let fileURL = tempDir.appendingPathComponent("native-config.json")
        let contents = try XCTUnwrap(String(contentsOf: fileURL, encoding: .utf8))
        XCTAssertTrue(contents.contains("\"stop_ref\""))
        XCTAssertTrue(contents.contains("\"stop_name\""))
    }

    func testAPIKeyRoundTripsThroughKeychainNotThePlaintextFile() throws {
        let config = Config(directory: tempDir, keychainService: testKeychainService)
        try config.setAPIKey("secret-123")
        XCTAssertEqual(config.apiKey, "secret-123")

        config.setStop(stopRef: "8507000", stopName: "Bern") // triggers a save()
        let fileURL = tempDir.appendingPathComponent("native-config.json")
        let contents = try XCTUnwrap(String(contentsOf: fileURL, encoding: .utf8))
        XCTAssertFalse(contents.contains("secret-123"), "API key must never be written to the plaintext config file")
    }

    func testEnvironmentAPIKeyTakesPriorityOverKeychain() throws {
        setenv("TRANSIT_ETA_API_KEY", "from-env", 1)
        defer { unsetenv("TRANSIT_ETA_API_KEY") }
        let config = Config(directory: tempDir, keychainService: testKeychainService)
        try config.setAPIKey("from-keychain")
        XCTAssertEqual(config.apiKey, "from-env")
    }
}
