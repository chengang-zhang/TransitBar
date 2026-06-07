import SwiftUI

struct FavoritesWindowView: View {
    @ObservedObject var viewModel: TransitBarViewModel
    @State private var selectedSection: TransitBarSection?
    @State private var visibleDepartureCountsByStopId: [String: Int] = [:]
    @State private var visibleLineStopDepartureCount = 3

    private let defaultVisibleDepartureCount = 3
    private let departureExpansionIncrement = 3
    private let lineGridColumns = [
        GridItem(.adaptive(minimum: 104, maximum: 118), spacing: 12)
    ]

    init(viewModel: TransitBarViewModel) {
        self.viewModel = viewModel
        _selectedSection = State(initialValue: viewModel.favorites.isEmpty ? .browse : .favorites)
    }

    private var lineSections: [LineResultSection] {
        Dictionary(grouping: viewModel.lineResults, by: \.sourceName)
            .map { sourceName, lines in
                LineResultSection(
                    sourceName: sourceName,
                    lines: lines.sorted {
                        $0.name.localizedStandardCompare($1.name) == .orderedAscending
                    }
                )
            }
            .sorted {
                $0.sourceName.localizedStandardCompare($1.sourceName) == .orderedAscending
            }
    }

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            selectedDetailView
        }
        .frame(minWidth: 1080, minHeight: 560)
    }

    private var sidebar: some View {
        List(selection: $selectedSection) {
            ForEach(TransitBarSection.allCases) { section in
                Label(section.title, systemImage: section.systemImage)
                    .tag(section as TransitBarSection?)
            }
        }
        .navigationTitle("TransitBar")
    }

    @ViewBuilder
    private var selectedDetailView: some View {
        switch selectedSection ?? .favorites {
        case .favorites:
            favoritesPanel
                .navigationTitle("Favorites")
        case .browse:
            searchPanel
                .navigationTitle("Browse")
        }
    }

    private var favoritesPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            if viewModel.favorites.isEmpty {
                ContentUnavailableView(
                    "No Favorite Stops",
                    systemImage: "star",
                    description: Text("Browse routes and add stops to track departures.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(viewModel.favorites) { favorite in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .firstTextBaseline, spacing: 10) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(favorite.stopName)
                                        .font(.headline)
                                        .lineLimit(2)

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

                            if let section = departureSection(for: favorite), !section.departures.isEmpty {
                                VStack(alignment: .leading, spacing: 4) {
                                    ForEach(visibleDepartures(in: section, for: favorite)) { departure in
                                        HStack(spacing: 8) {
                                            RouteBadgeView(departure: departure)
                                            Text(viewModel.formattedDepartureLine(for: departure))
                                                .lineLimit(1)
                                            Spacer()
                                            Text(viewModel.departureTimeText(for: departure.departureTime))
                                                .foregroundStyle(.secondary)
                                        }
                                        .font(.caption)
                                    }

                                    if section.departures.count > defaultVisibleDepartureCount {
                                        HStack(spacing: 12) {
                                            if visibleDepartureLimit(for: favorite) < section.departures.count {
                                                Button("See more arrivals") {
                                                    showMoreDepartures(for: favorite, totalCount: section.departures.count)
                                                }
                                                .buttonStyle(.borderless)
                                            }

                                            if visibleDepartureLimit(for: favorite) > defaultVisibleDepartureCount {
                                                Button("Collapse") {
                                                    collapseDepartures(for: favorite)
                                                }
                                                .buttonStyle(.borderless)
                                            }
                                        }
                                        .font(.caption)
                                        .padding(.top, 2)
                                    }
                                }
                            } else {
                                Text(viewModel.isLoadingDepartures ? "Loading departures..." : "No scheduled departures found.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 6)
                    }
                }
                .listStyle(.inset)
            }
        }
        .padding()
    }

    private var searchPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Mode", selection: $viewModel.stopSearchFilter) {
                ForEach(StopSearchFilter.allCases) { filter in
                    Text(filter.title).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: viewModel.stopSearchFilter) {
                viewModel.scheduleLineSearch(clearingSelection: true)
            }

            TextField("Search route name or number", text: $viewModel.searchQuery)
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

            HStack(alignment: .top, spacing: 12) {
                routeResultsPane
                    .frame(minWidth: 360, maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

                Divider()

                stopsPane
                    .frame(width: 390, alignment: .topLeading)
                    .frame(maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity)
            .onAppear {
                viewModel.scheduleLineSearch()
            }
        }
        .padding()
    }

    private func departureSection(for favorite: FavoriteStop) -> StopDeparturesSection? {
        viewModel.departureSections.first { $0.favorite.id == favorite.id }
    }

    private func visibleDepartures(in section: StopDeparturesSection, for favorite: FavoriteStop) -> [Departure] {
        Array(section.departures.prefix(visibleDepartureLimit(for: favorite)))
    }

    private func visibleDepartureLimit(for favorite: FavoriteStop) -> Int {
        visibleDepartureCountsByStopId[favorite.stopId] ?? defaultVisibleDepartureCount
    }

    private func showMoreDepartures(for favorite: FavoriteStop, totalCount: Int) {
        let nextCount = visibleDepartureLimit(for: favorite) + departureExpansionIncrement
        visibleDepartureCountsByStopId[favorite.stopId] = min(nextCount, totalCount)
    }

    private func collapseDepartures(for favorite: FavoriteStop) {
        visibleDepartureCountsByStopId[favorite.stopId] = defaultVisibleDepartureCount
    }

    private var routeResultsPane: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                ForEach(lineSections) { section in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(section.sourceName)
                            .font(.headline)
                            .foregroundStyle(.secondary)

                        LazyVGrid(columns: lineGridColumns, alignment: .leading, spacing: 8) {
                            ForEach(section.lines) { line in
                                routeButton(for: line)
                            }
                        }
                    }
                }
            }
            .padding(.vertical, 6)
            .padding(.trailing, 8)
        }
    }

    private func routeButton(for line: TransitLine) -> some View {
        Button {
            viewModel.selectLine(line)
        } label: {
            VStack(spacing: 4) {
                RouteBadgeView(line: line)
                Text(line.name)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, minHeight: 84, alignment: .top)
            .padding(.vertical, 6)
            .padding(.horizontal, 6)
            .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(viewModel.selectedLine?.id == line.id ? Color.accentColor.opacity(0.18) : Color.clear)
        )
    }

    private var stopsPane: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let selectedLine = viewModel.selectedLine {
                HStack(spacing: 8) {
                    RouteBadgeView(line: selectedLine)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Stops")
                            .font(.headline)
                        Text(selectedLine.sourceName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                if !selectedLine.details.isEmpty {
                    Text(selectedLine.details)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Divider()

                if viewModel.isLoadingLineStops {
                    ProgressView()
                        .controlSize(.small)
                } else if viewModel.lineStops.isEmpty {
                    Text("No stops found.")
                        .foregroundStyle(.secondary)
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(viewModel.lineStops) { stop in
                                stopRow(for: stop)
                            }
                        }
                        .padding(.trailing, 6)
                    }
                }
            } else {
                Text("Stops")
                    .font(.headline)
                Text("Select a route.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Spacer()
            }
        }
        .padding(.leading, 10)
        .accessibilityLabel(viewModel.selectedLine.map { "Stops for \($0.name)" } ?? "Stops")
    }

    private func stopRow(for stop: TransitStop) -> some View {
        let isSelected = viewModel.selectedLineStop?.id == stop.id

        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Button {
                    visibleLineStopDepartureCount = defaultVisibleDepartureCount
                    viewModel.selectLineStop(stop)
                } label: {
                    Text(stop.name)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if viewModel.isFavorite(stop) {
                    Text("Added")
                        .foregroundStyle(.secondary)
                } else {
                    Button("Add") {
                        viewModel.addFavorite(from: stop)
                    }
                }
            }

            if isSelected {
                selectedStopArrivals
                    .padding(.leading, 8)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 5)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isSelected ? Color.accentColor.opacity(0.12) : Color.clear)
        )
    }

    @ViewBuilder
    private var selectedStopArrivals: some View {
        if viewModel.isLoadingLineStopDepartures {
            ProgressView()
                .controlSize(.small)
        } else if viewModel.selectedLineStopDepartures.isEmpty {
            Text("No scheduled arrivals found.")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(visibleLineStopDepartures) { departure in
                    HStack(spacing: 8) {
                        RouteBadgeView(departure: departure)
                        Text(viewModel.formattedDepartureLine(for: departure))
                            .lineLimit(1)
                        Spacer()
                        Text(viewModel.departureTimeText(for: departure.departureTime))
                            .foregroundStyle(.secondary)
                    }
                    .font(.caption)
                }

                if viewModel.selectedLineStopDepartures.count > defaultVisibleDepartureCount {
                    HStack(spacing: 12) {
                        if visibleLineStopDepartureCount < viewModel.selectedLineStopDepartures.count {
                            Button("See more arrivals") {
                                showMoreLineStopDepartures()
                            }
                            .buttonStyle(.borderless)
                        }

                        if visibleLineStopDepartureCount > defaultVisibleDepartureCount {
                            Button("Collapse") {
                                collapseLineStopDepartures()
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                    .font(.caption)
                    .padding(.top, 2)
                }
            }
        }
    }

    private var visibleLineStopDepartures: [Departure] {
        Array(viewModel.selectedLineStopDepartures.prefix(visibleLineStopDepartureCount))
    }

    private func showMoreLineStopDepartures() {
        visibleLineStopDepartureCount = min(
            visibleLineStopDepartureCount + departureExpansionIncrement,
            viewModel.selectedLineStopDepartures.count
        )
    }

    private func collapseLineStopDepartures() {
        visibleLineStopDepartureCount = defaultVisibleDepartureCount
    }
}

private struct LineResultSection: Identifiable {
    let sourceName: String
    let lines: [TransitLine]

    var id: String { sourceName }
}

private enum TransitBarSection: String, CaseIterable, Identifiable {
    case favorites
    case browse

    var id: Self { self }

    var title: String {
        switch self {
        case .favorites:
            return "Favorites"
        case .browse:
            return "Browse"
        }
    }

    var systemImage: String {
        switch self {
        case .favorites:
            return "star"
        case .browse:
            return "point.topleft.down.curvedto.point.bottomright.up"
        }
    }
}
