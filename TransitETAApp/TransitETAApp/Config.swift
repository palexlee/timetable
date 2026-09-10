import Foundation

struct ConfigData: Codable, Equatable {
    var stopRef: String?
    var stopName: String?
    var pinned: Pin?

    enum CodingKeys: String, CodingKey {
        case stopRef = "stop_ref"
        case stopName = "stop_name"
        case pinned
    }
}

/// Stop/pin persistence (JSON, a sibling of the Python plugin's own
/// config -- a distinct file, not shared, to avoid any cross-tool
/// corruption risk) plus the API key, which lives in the Keychain
/// instead of plaintext on disk. An env var always wins, matching the
/// Python tool, so the key never has to live in a file at all.
final class Config {
    private let fileURL: URL
    private let keychainService: String
    private let keychainAccount = "api-key"
    private var data: ConfigData

    var stopRef: String? { data.stopRef }
    var stopName: String? { data.stopName }
    var pinned: Pin? { data.pinned }

    var apiKey: String? {
        if let envKey = ProcessInfo.processInfo.environment["TRANSIT_ETA_API_KEY"], !envKey.isEmpty {
            return envKey
        }
        return KeychainStore.get(service: keychainService, account: keychainAccount)
    }

    init(directory: URL? = nil, keychainService: String = "local.transit-eta.app") {
        let base = directory ?? {
            if let override = ProcessInfo.processInfo.environment["TRANSIT_ETA_HOME"] {
                return URL(fileURLWithPath: override)
            }
            return FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(".config/transit-eta")
        }()
        self.fileURL = base.appendingPathComponent("native-config.json")
        self.keychainService = keychainService
        if let contents = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode(ConfigData.self, from: contents) {
            self.data = decoded
        } else {
            self.data = ConfigData()
        }
    }

    private func save() {
        let directory = fileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        guard let encoded = try? JSONEncoder().encode(data) else { return }
        try? encoded.write(to: fileURL, options: .atomic)
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
    }

    func setStop(stopRef: String, stopName: String) {
        data.stopRef = stopRef
        data.stopName = stopName
        data.pinned = nil
        save()
    }

    func setPin(_ pin: Pin) {
        data.pinned = pin
        save()
    }

    func clearPin() {
        data.pinned = nil
        save()
    }

    func setAPIKey(_ key: String) throws {
        try KeychainStore.set(service: keychainService, account: keychainAccount, value: key)
    }
}
