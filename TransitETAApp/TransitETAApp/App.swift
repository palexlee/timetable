import SwiftUI

@main
struct TransitETAApp: App {
    var body: some Scene {
        MenuBarExtra("Transit ETA", systemImage: "tram.fill") {
            Text("Transit ETA")
                .padding()
        }
    }
}
