import Foundation
import Combine

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var events: [StopEvent] = []
    @Published private(set) var errorMessage: String?
    private(set) var config: Config

    private var timer: Timer?
    // Guards against a stale in-flight refresh() overwriting a newer one's
    // result: nextDepartures(config:) reads config.stopRef synchronously
    // before its network await, so a request already in flight when the
    // user changes stops is still for the OLD stop -- if that stale
    // response resolves after the new stop's own refresh, it would
    // silently clobber the fresh data with old-stop departures. Only the
    // most recently *started* refresh is allowed to apply its result.
    private var refreshGeneration = 0

    init(config: Config = Config()) {
        self.config = config
        // Eagerly, not from a view's .onAppear: MenuBarExtra(.window) builds
        // its content lazily, so an .onAppear-driven start wouldn't fire
        // until the user first opened the dropdown, leaving the menu bar
        // stale from launch until that first click.
        startTimer()
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
        refreshGeneration += 1
        let generation = refreshGeneration

        guard config.apiKey != nil else {
            errorMessage = "No API key configured (set TRANSIT_ETA_API_KEY or use the menu)."
            events = []
            return
        }
        guard config.stopRef != nil else {
            errorMessage = "No stop configured yet."
            events = []
            return
        }
        do {
            let fetched = try await nextDepartures(config: config)
            guard generation == refreshGeneration else { return } // superseded by a newer refresh
            events = fetched
            errorMessage = nil
        } catch let error as OjpError {
            guard generation == refreshGeneration else { return }
            errorMessage = error.message
        } catch {
            guard generation == refreshGeneration else { return }
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
