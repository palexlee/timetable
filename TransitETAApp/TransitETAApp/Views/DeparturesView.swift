import AppKit
import SwiftUI

struct DeparturesView: View {
    @ObservedObject var model: AppModel
    @State private var showingSearch = false
    @State private var showingAPIKey = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider().overlay(Color.dividerLight)
            content
            Divider().overlay(Color.dividerLight)
            footer
        }
        .frame(width: 320)
        .background(Color.white)
        .preferredColorScheme(.light)
        .sheet(isPresented: $showingSearch) {
            StopSearchView(model: model, isPresented: $showingSearch)
        }
        .sheet(isPresented: $showingAPIKey) {
            APIKeyEntryView(model: model, isPresented: $showingAPIKey)
        }
    }

    @ViewBuilder
    private var content: some View {
        if let errorMessage = model.errorMessage {
            Text(errorMessage)
                .font(.sbb(13))
                .foregroundColor(.sbbRed)
                .padding(16)
        } else if model.events.isEmpty {
            Text("No upcoming departures found")
                .font(.sbb(13))
                .foregroundColor(.inkSecondary)
                .padding(16)
        } else {
            VStack(spacing: 0) {
                ForEach(model.events.prefix(5), id: \.self) { event in
                    DepartureRow(event: event, pin: model.config.pinned, now: Date()) {
                        model.pin(event)
                    }
                    Divider().overlay(Color.dividerFaint)
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 8) {
                Image("station").renderingMode(.template)
                    .resizable().aspectRatio(contentMode: .fit)
                    .foregroundColor(.inkPrimary)
                    .frame(width: 22, height: 22)
                Text(model.config.stopName ?? "Transit ETA")
                    .font(.sbb(16, weight: .bold))
                    .foregroundColor(.inkPrimary)
            }
            Text("NEXT DEPARTURES")
                .font(.sbb(10, weight: .bold))
                .foregroundColor(.inkSecondary)
                .tracking(1)
        }
        .padding(EdgeInsets(top: 14, leading: 16, bottom: 10, trailing: 16))
    }

    private var footer: some View {
        VStack(spacing: 0) {
            if model.config.pinned != nil {
                FooterAction(iconName: "circle-cross", title: "Unpin", destructive: true) {
                    model.unpin()
                }
                Divider().overlay(Color.dividerFaint)
            }
            FooterAction(iconName: "magnifying-glass", title: "Change stop…") {
                showingSearch = true
            }
            Divider().overlay(Color.dividerFaint)
            FooterAction(iconName: "refresh", title: "Refresh now") {
                Task { await model.refresh() }
            }
            Divider().overlay(Color.dividerFaint)
            FooterAction(iconName: "key", title: "Set API key…") {
                showingAPIKey = true
            }
            Divider().overlay(Color.dividerFaint)
            FooterAction(iconName: "circle-cross", title: "Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
    }
}

private struct DepartureRow: View {
    let event: StopEvent
    let pin: Pin?
    let now: Date
    let onSelect: () -> Void

    private var isPinned: Bool { event.matchesPin(pin) }

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                Image(event.iconName).renderingMode(.template)
                    .resizable().aspectRatio(contentMode: .fit)
                    .foregroundColor(.inkPrimary)
                    .frame(width: 24, height: 24)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(event.lineName)
                            .font(.sbb(13, weight: .bold))
                            .foregroundColor(.white)
                            .padding(EdgeInsets(top: 2, leading: 6, bottom: 2, trailing: 6))
                            .frame(minWidth: 22)
                            .background(lineBadgeColor(mode: event.mode, lineName: event.lineName))
                            .cornerRadius(4)
                        Text("→").font(.sbb(13)).foregroundColor(.inkSecondary)
                        Text(event.destination).font(.sbb(14)).foregroundColor(.inkPrimary).lineLimit(1)
                    }
                    HStack(spacing: 5) {
                        if let platform = event.platform {
                            Image("platform").renderingMode(.template)
                                .resizable().aspectRatio(contentMode: .fit)
                                .foregroundColor(Color(white: 0.68))
                                .frame(width: 13, height: 13)
                            Text("Gl. \(platform)").font(.sbb(12)).foregroundColor(.inkSecondary)
                            Text("·").font(.sbb(12)).foregroundColor(.inkSecondary)
                        }
                        Text(event.scheduledTime, style: .time).font(.sbb(12)).foregroundColor(.inkSecondary)
                    }
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 1) {
                    Text(compactETA(event.etaMinutes(now: now))).font(.sbb(18, weight: .bold)).foregroundColor(.inkPrimary)
                    if event.isDelayed {
                        Text("+\(event.delayMinutes)′").font(.sbb(11, weight: .bold)).foregroundColor(.sbbRed)
                    }
                }
                if isPinned {
                    Image("circle-tick").renderingMode(.template)
                        .resizable().aspectRatio(contentMode: .fit)
                        .foregroundColor(.sbbRed)
                        .frame(width: 16, height: 16)
                }
            }
            .padding(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
            .background(isPinned ? Color.pinnedTint : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct FooterAction: View {
    let iconName: String
    let title: String
    var destructive: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(iconName).renderingMode(.template)
                    .resizable().aspectRatio(contentMode: .fit)
                    .foregroundColor(destructive ? .sbbRed : Color(white: 0.29))
                    .frame(width: 16, height: 16)
                Text(title).font(.sbb(14))
                    .foregroundColor(destructive ? .sbbRed : .inkPrimary)
                Spacer(minLength: 0)
            }
            .padding(EdgeInsets(top: 11, leading: 16, bottom: 11, trailing: 16))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
