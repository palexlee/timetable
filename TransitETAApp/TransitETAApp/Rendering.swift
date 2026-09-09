import Foundation

enum MenuBarState: Equatable {
    case noStop
    case unpinned(stopName: String)
    case pinned(iconName: String, lineName: String, destination: String, etaText: String, delayText: String?)
    case notRunning(iconName: String, lineName: String, destination: String)
}

func compactETA(_ minutes: Int) -> String {
    minutes <= 0 ? "now" : "\(minutes)′"
}

/// Mirrors render.py's title_for(): what the menu bar itself should show.
func menuBarState(pin: Pin?, stopName: String?, events: [StopEvent], now: Date) -> MenuBarState {
    guard let pin else {
        guard let stopName else { return .noStop }
        return .unpinned(stopName: stopName)
    }
    guard let match = events.first(where: { $0.matchesPin(pin) }) else {
        // Pinned route isn't in the next N departures right now (e.g. big
        // gap between runs) -- show the icon with a dash rather than
        // silently falling back to a different line.
        return .notRunning(iconName: iconAssetName(forMode: pin.mode), lineName: pin.lineName, destination: pin.destination)
    }
    let etaText = compactETA(match.etaMinutes(now: now))
    let delayText = match.isDelayed ? "+\(match.delayMinutes)′" : nil
    return .pinned(iconName: match.iconName, lineName: match.lineName, destination: match.destination, etaText: etaText, delayText: delayText)
}
