import SwiftUI

struct MenuBarLabel: View {
    let state: MenuBarState

    var body: some View {
        HStack(spacing: 4) {
            switch state {
            case .noStop:
                icon("station")
                Text("Transit ETA")
            case .unpinned(let stopName):
                icon("station")
                Text(stopName)
            case .pinned(let iconName, let lineName, let destination, let etaText, let delayText):
                icon(iconName)
                Text("\(lineName) → \(destination) \(etaText)")
                if let delayText {
                    Text(delayText).foregroundColor(.sbbRed)
                }
            case .notRunning(let iconName, let lineName, let destination):
                icon(iconName)
                Text("\(lineName) → \(destination) –")
            }
        }
        .font(.sbb(13))
    }

    private func icon(_ name: String) -> some View {
        Image(name).renderingMode(.template)
            .resizable().aspectRatio(contentMode: .fit)
            .frame(width: 14, height: 14)
    }
}
