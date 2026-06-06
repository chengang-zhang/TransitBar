import SwiftUI

struct MenuBarContentView: View {
    @ObservedObject var viewModel: TransitBarViewModel
    @Environment(\.openWindow) private var openWindow
    private let menuWidth: CGFloat = 420
    private let contentHorizontalPadding: CGFloat = 16
    private let departureLineWidth: CGFloat = 268
    private let departureTimeWidth: CGFloat = 64

    private var contentWidth: CGFloat {
        menuWidth - (contentHorizontalPadding * 2)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.primary)
            } else if viewModel.favorites.isEmpty {
                Text("Add a favorite stop to get started.")
                    .foregroundStyle(.primary)
            } else if viewModel.departureSections.isEmpty {
                Text(viewModel.isLoadingDepartures ? "Loading departures..." : "No upcoming departures.")
                    .foregroundStyle(.primary.opacity(0.72))
                    .frame(width: contentWidth, alignment: .leading)
            } else if viewModel.departureSections.count > 3 {
                ScrollView {
                    departureSections
                }
                .frame(height: 360)
            } else {
                departureSections
            }

            Divider()

            Button("Open TransitBar") {
                openWindow(id: "favorites")
                surfaceTransitBarWindow()
            }
            .buttonStyle(.plain)
            .frame(width: contentWidth, alignment: .leading)

            Button("Refresh") {
                viewModel.refreshDepartures()
            }
            .buttonStyle(.plain)
            .frame(width: contentWidth, alignment: .leading)

            Divider()

            Button("Quit TransitBar") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
            .frame(width: contentWidth, alignment: .leading)
        }
        .frame(width: contentWidth)
        .padding(.horizontal, contentHorizontalPadding)
        .padding(.vertical, 10)
        .onAppear {
            viewModel.refreshDepartures()
        }
    }

    private var departureSections: some View {
        ForEach(viewModel.departureSections) { section in
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(section.favorite.stopName)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    if viewModel.isPrimary(section.favorite) {
                        Text("Primary")
                            .font(.caption)
                            .foregroundStyle(.primary.opacity(0.72))
                            .fixedSize()
                    }
                }
                .frame(width: contentWidth, alignment: .leading)

                if section.departures.isEmpty {
                    Text("No upcoming departures.")
                        .foregroundStyle(.primary.opacity(0.72))
                } else {
                    ForEach(section.departures.prefix(2)) { departure in
                        HStack(alignment: .center, spacing: 10) {
                            RouteBadgeView(departure: departure)
                            Text(departure.destination)
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .foregroundStyle(.primary)
                                .frame(width: departureLineWidth, alignment: .leading)
                            Text(viewModel.minutesText(for: departure.departureTime))
                                .monospacedDigit()
                                .fontWeight(.semibold)
                                .foregroundStyle(.primary)
                                .frame(width: departureTimeWidth, alignment: .trailing)
                        }
                        .frame(width: contentWidth, alignment: .leading)
                        .padding(.vertical, 2)
                    }
                }
            }
            .frame(width: contentWidth, alignment: .leading)

            if section.id != viewModel.departureSections.last?.id {
                Divider()
            }
        }
    }

    private func surfaceTransitBarWindow() {
        DispatchQueue.main.async {
            NSApplication.shared.activate()
            NSApplication.shared.windows
                .first { $0.title == "TransitBar" }?
                .makeKeyAndOrderFront(nil)
        }
    }
}
