import SwiftUI

struct FavoritesWindowView: View {
    @ObservedObject var viewModel: TransitBarViewModel

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
            TextField("Search stops", text: $viewModel.searchQuery)
                .textFieldStyle(.roundedBorder)
                .onSubmit {
                    viewModel.searchStops()
                }
                .onChange(of: viewModel.searchQuery) {
                    viewModel.searchStops()
                }

            if viewModel.isSearching {
                ProgressView()
                    .controlSize(.small)
            }

            List(viewModel.searchResults) { stop in
                HStack {
                    Text(stop.name)
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
        .padding()
    }
}
