import Foundation

/// OJP `PtMode` values -> the matching SBB pictogram asset name, pulled
/// from sbb-design-systems/sbb-icons (Apache-2.0). "station" is the
/// generic fallback for any mode without a dedicated icon.
func iconAssetName(forMode mode: String) -> String {
    switch mode.trimmingCharacters(in: .whitespaces).lowercased() {
    case "rail", "suburbanrail": return "train-profile"
    case "tram": return "tram-profile"
    case "bus", "coach": return "bus-profile"
    case "metro", "underground": return "underground-vehicule-profile"
    case "water": return "boat-profile"
    case "cableway": return "cable-car-profile"
    case "funicular": return "funicular-profile"
    default: return "station"
    }
}

/// A single upcoming departure at a stop.
struct StopEvent: Hashable {
    let mode: String
    let lineName: String
    let destination: String
    let scheduledTime: Date
    let estimatedTime: Date?
    let platform: String?

    var bestTime: Date { estimatedTime ?? scheduledTime }

    var isDelayed: Bool {
        guard let estimatedTime else { return false }
        return estimatedTime > scheduledTime
    }

    var delayMinutes: Int {
        guard isDelayed, let estimatedTime else { return 0 }
        let delta = estimatedTime.timeIntervalSince(scheduledTime)
        return max(0, Int((delta / 60).rounded()))
    }

    var iconName: String { iconAssetName(forMode: mode) }

    func etaMinutes(now: Date) -> Int {
        let delta = bestTime.timeIntervalSince(now)
        return max(0, Int((delta / 60).rounded()))
    }

    private static func normalized(_ text: String) -> String {
        text.precomposedStringWithCanonicalMapping // NFC
    }

    /// Whether this event belongs to the same route+destination as `pin`.
    /// macOS hands back accented text from a click's args as NFD, while
    /// the OJP API sends NFC -- normalize both sides before comparing.
    func matchesPin(_ pin: Pin?) -> Bool {
        guard let pin else { return false }
        return mode == pin.mode
            && Self.normalized(lineName) == Self.normalized(pin.lineName)
            && Self.normalized(destination) == Self.normalized(pin.destination)
    }
}

/// A candidate stop returned by the location search.
struct StopMatch: Hashable {
    let stopRef: String
    let name: String
    let probability: Double?
}

struct Pin: Codable, Equatable, Hashable {
    let mode: String
    let lineName: String
    let destination: String

    enum CodingKeys: String, CodingKey {
        case mode
        case lineName = "line_name"
        case destination
    }
}
