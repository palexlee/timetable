import AppKit
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
                // A single Text run, delay included: a status item's label
                // silently drops a differently-colored second Text run
                // (confirmed live -- the dropdown's identical two-color
                // layout works fine, only the menu bar title lost the
                // delay entirely), so the delay minutes show here in the
                // same color rather than not showing at all. Same reason
                // the line-badge coloring stays dropdown-only: MenuBarExtra
                // coerces its whole label to monochrome regardless of an
                // image's own isTemplate flag (confirmed live -- even a
                // pre-rasterized, non-template badge image lost its color).
                if let delayText {
                    Text("\(lineName) → \(destination) \(etaText) \(delayText)")
                } else {
                    Text("\(lineName) → \(destination) \(etaText)")
                }
            case .notRunning(let iconName, let lineName, let destination):
                icon(iconName)
                Text("\(lineName) → \(destination) –")
            }
        }
        .font(.sbb(13))
    }

    private func icon(_ name: String) -> some View {
        // SwiftUI's .resizable()/.frame()/.clipped() chain did not reliably
        // constrain a vector asset's size inside a MenuBarExtra label (the
        // identical chain works fine on the same assets in the dropdown --
        // confirmed live), so force the NSImage's own intrinsic size before
        // SwiftUI ever sees it, which the status item respects.
        let nsImage = NSImage(named: name) ?? NSImage()
        nsImage.size = NSSize(width: 13, height: 13)
        nsImage.isTemplate = true
        return Image(nsImage: nsImage)
    }
}
