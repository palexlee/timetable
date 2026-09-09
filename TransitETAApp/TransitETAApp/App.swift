import SwiftUI

@main
struct TransitETAMenuBarApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        MenuBarExtra {
            DeparturesView(model: model)
                .onAppear { model.startTimer() }
        } label: {
            MenuBarLabel(state: model.menuBarLabelState)
        }
        .menuBarExtraStyle(.window)
    }
}
