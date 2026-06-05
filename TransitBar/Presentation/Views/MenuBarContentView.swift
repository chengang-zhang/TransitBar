import SwiftUI

struct MenuBarContentView: View {
    @ObservedObject var viewModel: TransitBarViewModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.secondary)
            } else if viewModel.favorites.isEmpty {
                Text("Add a favorite stop to get started.")
                    .foregroundStyle(.secondary)
            } else {
                departureSections
            }

            Divider()

            Button("Add Favorite Stop") {
                openWindow(id: "favorites")
            }

            Button("Manage Favorites") {
                openWindow(id: "favorites")
            }

            Button("Refresh") {
                viewModel.refreshDepartures()
            }

            Divider()

            Button("Quit TransitBar") {
                NSApplication.shared.terminate(nil)
            }
        }
        .frame(minWidth: 320)
        .padding(.vertical, 6)
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
                    if viewModel.isPrimary(section.favorite) {
                        Text("Primary")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if section.departures.isEmpty {
                    Text("No upcoming departures.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(section.departures.prefix(4)) { departure in
                        HStack {
                            Text(viewModel.formattedDepartureLine(for: departure))
                                .lineLimit(1)
                            Spacer()
                            Text(viewModel.minutesText(for: departure.departureTime))
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            if section.id != viewModel.departureSections.last?.id {
                Divider()
            }
        }
    }
}
