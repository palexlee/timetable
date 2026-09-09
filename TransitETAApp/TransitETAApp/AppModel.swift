import Foundation
import Combine

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var events: [StopEvent] = []
    @Published private(set) var errorMessage: String?
    private(set) var config: Config

    private var timer: Timer?

    init(config: Config = Config()) {
        self.config = config
    }

    // Named differently from the free function `menuBarState(pin:...)` in
    // Rendering.swift: Swift's unqualified lookup inside a type body favors
    // a same-named member over a module-scope function regardless of the
    // call's argument labels, and module-qualifying it doesn't help either
    // since the app's `@main` struct is also named `TransitETAApp` until
    // Task 10 renames it. Renaming this property sidesteps the collision.
    var menuBarLabelState: MenuBarState {
        menuBarState(pin: config.pinned, stopName: config.stopName, events: events, now: Date())
    }

    func startTimer(interval: TimeInterval = 10) {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.refresh() }
        }
        Task { await refresh() }
    }

    func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    /// Always resolves to either updated events or an error message --
    /// never throws, never crashes. This app polls on a timer, so a single
    /// bad response must never take the whole loop down (the lesson from
    /// the Python plugin's xml_util.parse fix).
    func refresh() async {
        guard config.apiKey != nil else {
            errorMessage = "No API key configured (set TRANSIT_ETA_API_KEY or use the menu)."
            return
        }
        guard config.stopRef != nil else {
            errorMessage = "No stop configured yet."
            return
        }
        do {
            events = try await nextDepartures(config: config)
            errorMessage = nil
        } catch let error as OjpError {
            errorMessage = error.message
        } catch {
            errorMessage = "Unexpected error: \(error.localizedDescription)"
        }
    }

    func search(_ query: String) async throws -> [StopMatch] {
        try await searchStops(config: config, query: query)
    }

    func selectStop(_ match: StopMatch) async {
        config.setStop(stopRef: match.stopRef, stopName: match.name)
        objectWillChange.send()
        await refresh()
    }

    func pin(_ event: StopEvent) {
        objectWillChange.send()
        config.setPin(Pin(mode: event.mode, lineName: event.lineName, destination: event.destination))
    }

    func unpin() {
        objectWillChange.send()
        config.clearPin()
    }

    func setAPIKey(_ key: String) throws {
        try config.setAPIKey(key)
    }
}
