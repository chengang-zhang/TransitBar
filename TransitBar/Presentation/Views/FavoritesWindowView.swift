import SwiftUI

struct FavoritesWindowView: View {
    @ObservedObject var viewModel: TransitBarViewModel
    private let lineGridColumns = [
        GridItem(.adaptive(minimum: 72), spacing: 8)
    ]

    var body: some View {
        NavigationSplitView {
            favoritesList
                .navigationTitle("Favorites")
        } detail: {
            searchPanel
                .navigationTitle("Add Stop")
        }
        .frame(minWidth: 760, minHeight: 460)
    }

    private var favoritesList: some View {
        List {
            if viewModel.favorites.isEmpty {
                Text("Add a favorite stop to get started.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.favorites) { favorite in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(favorite.stopName)
                            if viewModel.isPrimary(favorite) {
                                Text("Primary stop")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer()

                        if !viewModel.isPrimary(favorite) {
                            Button("Set Primary") {
                                viewModel.setPrimaryStop(favorite)
                            }
                        }

                        Button(role: .destructive) {
                            viewModel.removeFavorite(favorite)
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private var searchPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Stop type", selection: $viewModel.stopSearchFilter) {
                ForEach(StopSearchFilter.allCases) { filter in
                    Text(filter.title).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: viewModel.stopSearchFilter) {
                viewModel.scheduleLineSearch(clearingSelection: true)
            }

            TextField("Search line or bus number", text: $viewModel.searchQuery)
                .textFieldStyle(.roundedBorder)
                .onSubmit {
                    viewModel.scheduleLineSearch()
                }
                .onChange(of: viewModel.searchQuery) {
                    viewModel.scheduleLineSearch(clearingSelection: true)
                }

            if viewModel.isSearching {
                ProgressView()
                    .controlSize(.small)
            }

            ScrollView {
                LazyVGrid(columns: lineGridColumns, alignment: .leading, spacing: 8) {
                    ForEach(viewModel.lineResults) { line in
                        Button {
                            viewModel.selectLine(line)
                        } label: {
                            VStack(spacing: 4) {
                                RouteBadgeView(line: line)
                                Text(line.name)
                                    .font(.caption)
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 4)
                            .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(viewModel.selectedLine?.id == line.id ? Color.accentColor.opacity(0.18) : Color.clear)
                        )
                    }
                }
                .padding(.vertical, 4)

                if let selectedLine = viewModel.selectedLine {
                    Divider()
                        .padding(.vertical, 6)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            RouteBadgeView(line: selectedLine)
                            Text("Stops")
                                .font(.headline)
                            if !selectedLine.details.isEmpty {
                                Text(selectedLine.details)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }

                        if viewModel.isLoadingLineStops {
                            ProgressView()
                                .controlSize(.small)
                        } else if viewModel.lineStops.isEmpty {
                            Text("No stops found.")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(viewModel.lineStops) { stop in
                                HStack {
                                    Text(stop.name)
                                        .lineLimit(1)
                                    Spacer()

                                    if viewModel.isFavorite(stop) {
                                        Text("Added")
                                            .foregroundStyle(.secondary)
                                    } else {
                                        Button("Add") {
                                            viewModel.addFavorite(from: stop)
                                        }
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                    .accessibilityLabel("Stops for \(selectedLine.name)")
                }
            }
            .frame(maxWidth: .infinity)
            .onAppear {
                viewModel.scheduleLineSearch()
            }
        }
        .padding()
    }
}
