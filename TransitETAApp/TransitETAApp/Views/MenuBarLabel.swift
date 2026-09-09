import SwiftUI

struct MenuBarLabel: View {
    let state: MenuBarState

    var body: some View {
        HStack(spacing: 4) {
            switch state {
            case .noStop:
                Image("station").renderingMode(.template)
                Text("Transit ETA")
            case .unpinned(let stopName):
                Image("station").renderingMode(.template)
                Text(stopName)
            case .pinned(let iconName, let lineName, let destination, let etaText, let delayText):
                Image(iconName).renderingMode(.template)
                Text("\(lineName) → \(destination) \(etaText)")
                if let delayText {
                    Text(delayText).foregroundColor(.sbbRed)
                }
            case .notRunning(let iconName, let lineName, let destination):
                Image(iconName).renderingMode(.template)
                Text("\(lineName) → \(destination) –")
            }
        }
        .font(.sbb(13))
    }
}
