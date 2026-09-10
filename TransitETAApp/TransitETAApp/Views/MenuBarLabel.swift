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
                badge(iconName: iconName, lineName: lineName)
                // A single Text run, delay included: a status item's label
                // silently drops a differently-colored second Text run
                // (confirmed live -- the dropdown's identical two-color
                // layout works fine, only the menu bar title lost the
                // delay entirely), so the delay minutes show here in the
                // same color rather than not showing at all.
                if let delayText {
                    Text("→ \(destination) \(etaText) \(delayText)")
                } else {
                    Text("→ \(destination) \(etaText)")
                }
            case .notRunning(let iconName, let lineName, let destination):
                icon(iconName)
                badge(iconName: iconName, lineName: lineName)
                Text("→ \(destination) –")
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

    private func badge(iconName: String, lineName: String) -> some View {
        // Pre-rasterize the badge into a bitmap and show it as a plain
        // (non-template) Image, the same way `icon(_:)` works around the
        // status item dropping composed/colored content: a differently
        // colored second Text run was confirmed dropped outright, so a
        // live Text+background+cornerRadius badge is the same risk --
        // rendering it to an NSImage first sidesteps that entirely.
        let content = Text(lineName)
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(.white)
            .padding(EdgeInsets(top: 1, leading: 4, bottom: 1, trailing: 4))
            .frame(minWidth: 18)
            .background(lineBadgeColor(iconName: iconName, lineName: lineName))
            .cornerRadius(3)
        let renderer = ImageRenderer(content: content)
        renderer.scale = 2
        return Image(nsImage: renderer.nsImage ?? NSImage())
    }
}
