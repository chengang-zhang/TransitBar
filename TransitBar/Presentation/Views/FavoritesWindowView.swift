#if ST_REALTIME_TEST
import Combine
#endif
import SwiftUI

struct FavoritesWindowView: View {
    @ObservedObject var viewModel: TransitBarViewModel
    #if ST_REALTIME_TEST
    @StateObject private var soundTransitRealtimeDebugViewModel: SoundTransitRealtimeDebugViewModel
    @StateObject private var kingCountyRealtimeDebugViewModel: SoundTransitRealtimeDebugViewModel
    #endif
    @State private var selectedSection: TransitBarSection?
    @State private var visibleDepartureCountsByStopId: [String: Int] = [:]
    @State private var visibleLineStopDepartureCount = 3

    private let departureExpansionIncrement = 3
    private let refreshIntervals: [TimeInterval] = [30, 60, 120, 300]
    private let maxDepartureOptions = Array(1...6)
    private let lineGridColumns = [
        GridItem(.adaptive(minimum: 104, maximum: 118), spacing: 12)
    ]

    init(viewModel: TransitBarViewModel) {
        self.viewModel = viewModel
        #if ST_REALTIME_TEST
        _soundTransitRealtimeDebugViewModel = StateObject(
            wrappedValue: SoundTransitRealtimeDebugViewModel(
                agencyName: "Sound Transit",
                provider: SoundTransitRealtimeProvider(configuration: .soundTransit)
            )
        )
        _kingCountyRealtimeDebugViewModel = StateObject(
            wrappedValue: SoundTransitRealtimeDebugViewModel(
                agencyName: "King County Metro",
                provider: SoundTransitRealtimeProvider(configuration: .kingCountyMetro)
            )
        )
        #endif
        _selectedSection = State(initialValue: viewModel.favorites.isEmpty ? .browse : .favorites)
        _visibleLineStopDepartureCount = State(initialValue: viewModel.maxDeparturesPerStop)
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
        VStack(spacing: 0) {
            List(selection: $selectedSection) {
                ForEach(TransitBarSection.primarySections) { section in
                    sidebarLabel(for: section)
                }
            }
            .scrollDisabled(true)

            Spacer(minLength: 0)

            Divider()

            List(selection: $selectedSection) {
                ForEach(TransitBarSection.bottomSections) { section in
                    sidebarLabel(for: section)
                }
            }
            .scrollDisabled(true)
            .frame(height: CGFloat(TransitBarSection.bottomSections.count) * 44 + 10)
        }
        .navigationTitle("TransitBar")
    }

    private func sidebarLabel(for section: TransitBarSection) -> some View {
        Label(section.title, systemImage: section.systemImage)
            .tag(section as TransitBarSection?)
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
        #if ST_REALTIME_TEST
        case .soundTransitRealtime:
            soundTransitRealtimePanel
                .navigationTitle("Sound Transit Realtime")
        case .kingCountyMetroRealtime:
            kingCountyRealtimePanel
                .navigationTitle("King County Metro Realtime")
        #endif
        case .settings:
            settingsPanel
                .navigationTitle("Settings")
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

                                if let section = departureSection(for: favorite), !section.alerts.isEmpty {
                                    alertMenu(for: section.alerts, title: viewModel.alertTitle(for: section))
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
                                            predictionSourceLabel(for: departure)
                                        }
                                        .font(.caption)
                                    }

                                    if section.departures.count > viewModel.maxDeparturesPerStop {
                                        HStack(spacing: 12) {
                                            if visibleDepartureLimit(for: favorite) < section.departures.count {
                                                Button("See more arrivals") {
                                                    showMoreDepartures(for: favorite, totalCount: section.departures.count)
                                                }
                                                .buttonStyle(.borderless)
                                            }

                                            if visibleDepartureLimit(for: favorite) > viewModel.maxDeparturesPerStop {
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

    #if ST_REALTIME_TEST
    private var soundTransitRealtimePanel: some View {
        realtimePanel(for: soundTransitRealtimeDebugViewModel)
    }

    private var kingCountyRealtimePanel: some View {
        realtimePanel(for: kingCountyRealtimeDebugViewModel)
    }

    private func realtimePanel(for debugViewModel: SoundTransitRealtimeDebugViewModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(debugViewModel.agencyName) GTFS-Realtime")
                        .font(.headline)
                    Text(debugViewModel.summaryText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    debugViewModel.loadRealtimeData(forceRefresh: true)
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(debugViewModel.isLoading)
            }

            if let errorMessage = debugViewModel.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            if debugViewModel.isLoading && debugViewModel.rows.isEmpty {
                ProgressView()
                    .controlSize(.small)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if debugViewModel.errorMessage != nil && debugViewModel.rows.isEmpty {
                ContentUnavailableView(
                    "Realtime Feed Unavailable",
                    systemImage: "wifi.exclamationmark",
                    description: Text("TransitBar could not reach the \(debugViewModel.agencyName) realtime feed.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if debugViewModel.rows.isEmpty {
                ContentUnavailableView(
                    "No Realtime Trip Updates",
                    systemImage: "antenna.radiowaves.left.and.right",
                    description: Text("The \(debugViewModel.agencyName) feed did not return any stop time updates.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    if !debugViewModel.alertRows.isEmpty {
                        Section("Alerts") {
                            ForEach(debugViewModel.alertRows) { row in
                                realtimeAlertRow(row)
                            }
                        }
                    }

                    ForEach(debugViewModel.sections) { section in
                        Section(section.title) {
                            ForEach(section.rows) { row in
                                realtimeTripUpdateRow(row)
                            }
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
        .padding()
        .onAppear {
            debugViewModel.loadRealtimeData()
        }
    }

    private func realtimeTripUpdateRow(_ row: SoundTransitRealtimeDebugRow) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(row.routeId)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.accentColor, in: Capsule())

                Text(row.displayTime)
                    .font(.headline)

                Spacer()

                if let delayText = row.delayText {
                    Text(delayText)
                        .font(.caption)
                        .foregroundStyle(row.delayIsLate ? .orange : .green)
                }

                Text(row.stopRelationship)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                Text("Stop \(row.stopId)")
                Text("Trip \(row.tripId)")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)

            HStack(spacing: 12) {
                Text("Direction \(row.directionText)")
                Text(row.tripRelationship)
            }
            .font(.caption2)
            .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 5)
    }

    private func realtimeAlertRow(_ row: SoundTransitRealtimeDebugAlertRow) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.yellow)

                Text(row.title)
                    .font(.headline)
                    .lineLimit(2)
            }

            if let description = row.description {
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }

            HStack(spacing: 12) {
                Text(row.routeText)
                Text(row.stopText)
            }
            .font(.caption2)
            .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 5)
    }
    #endif

    private var settingsPanel: some View {
        Form {
            Picker(
                "Refresh",
                selection: Binding(
                    get: { viewModel.refreshInterval },
                    set: { viewModel.setRefreshInterval($0) }
                )
            ) {
                ForEach(refreshIntervals, id: \.self) { interval in
                    Text(refreshIntervalTitle(interval)).tag(interval)
                }
            }
            .pickerStyle(.segmented)

            Toggle(
                "Show seconds under 5 minutes",
                isOn: Binding(
                    get: { viewModel.showsSecondsForNearDepartures },
                    set: { viewModel.setShowsSecondsForNearDepartures($0) }
                )
            )

            Picker(
                "Arrivals per stop",
                selection: Binding(
                    get: { viewModel.maxDeparturesPerStop },
                    set: { viewModel.setMaxDeparturesPerStop($0) }
                )
            ) {
                ForEach(maxDepartureOptions, id: \.self) { count in
                    Text("\(count)").tag(count)
                }
            }
            .pickerStyle(.segmented)
        }
        .formStyle(.grouped)
        .padding()
        .frame(maxWidth: 520, maxHeight: .infinity, alignment: .topLeading)
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
        visibleDepartureCountsByStopId[favorite.stopId] ?? viewModel.maxDeparturesPerStop
    }

    private func showMoreDepartures(for favorite: FavoriteStop, totalCount: Int) {
        let nextCount = visibleDepartureLimit(for: favorite) + departureExpansionIncrement
        visibleDepartureCountsByStopId[favorite.stopId] = min(nextCount, totalCount)
    }

    private func collapseDepartures(for favorite: FavoriteStop) {
        visibleDepartureCountsByStopId[favorite.stopId] = viewModel.maxDeparturesPerStop
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
                    visibleLineStopDepartureCount = viewModel.maxDeparturesPerStop
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
                        predictionSourceLabel(for: departure)
                    }
                    .font(.caption)
                }

                if viewModel.selectedLineStopDepartures.count > viewModel.maxDeparturesPerStop {
                    HStack(spacing: 12) {
                        if visibleLineStopDepartureCount < viewModel.selectedLineStopDepartures.count {
                            Button("See more arrivals") {
                                showMoreLineStopDepartures()
                            }
                            .buttonStyle(.borderless)
                        }

                        if visibleLineStopDepartureCount > viewModel.maxDeparturesPerStop {
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
        visibleLineStopDepartureCount = viewModel.maxDeparturesPerStop
    }

    private func refreshIntervalTitle(_ interval: TimeInterval) -> String {
        switch interval {
        case 30:
            return "30s"
        case 60:
            return "1m"
        case 120:
            return "2m"
        case 300:
            return "5m"
        default:
            return "\(Int(interval))s"
        }
    }

    private func predictionSourceLabel(for departure: Departure) -> some View {
        Text(departure.predictionSource.displayTitle)
            .font(.caption2)
            .foregroundStyle(predictionSourceColor(for: departure))
    }

    private func predictionSourceColor(for departure: Departure) -> Color {
        switch departure.predictionSource {
        case .realtime:
            return .green
        case .canceled, .skipped:
            return .red
        case .scheduled:
            return .secondary
        }
    }

    private func alertMenu(for alerts: [RealtimeAlert], title: String) -> some View {
        Menu {
            ForEach(alerts, id: \.id) { alert in
                VStack(alignment: .leading) {
                    Text(alert.headerText ?? "Service alert")
                    if let descriptionText = alert.descriptionText, !descriptionText.isEmpty {
                        Text(descriptionText)
                    }
                    if !alert.routeIds.isEmpty {
                        Text("Routes: \(alert.routeIds.sorted().joined(separator: ", "))")
                    }
                    if !alert.stopIds.isEmpty {
                        Text("Stops: \(alert.stopIds.sorted().joined(separator: ", "))")
                    }
                }
            }
        } label: {
            Label(title, systemImage: "exclamationmark.triangle.fill")
                .labelStyle(.iconOnly)
                .foregroundStyle(.yellow)
        }
        .menuStyle(.borderlessButton)
        .help(title)
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
    #if ST_REALTIME_TEST
    case soundTransitRealtime
    case kingCountyMetroRealtime
    #endif
    case settings

    var id: Self { self }

    static var primarySections: [TransitBarSection] {
        [.favorites, .browse]
    }

    static var bottomSections: [TransitBarSection] {
        #if ST_REALTIME_TEST
        [.soundTransitRealtime, .kingCountyMetroRealtime, .settings]
        #else
        [.settings]
        #endif
    }

    var title: String {
        switch self {
        case .favorites:
            return "Favorites"
        case .browse:
            return "Browse"
        #if ST_REALTIME_TEST
        case .soundTransitRealtime:
            return "ST Realtime"
        case .kingCountyMetroRealtime:
            return "Metro Realtime"
        #endif
        case .settings:
            return "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .favorites:
            return "star"
        case .browse:
            return "point.topleft.down.curvedto.point.bottomright.up"
        #if ST_REALTIME_TEST
        case .soundTransitRealtime:
            return "antenna.radiowaves.left.and.right"
        case .kingCountyMetroRealtime:
            return "bus.fill"
        #endif
        case .settings:
            return "gearshape"
        }
    }
}

#if ST_REALTIME_TEST
@MainActor
private final class SoundTransitRealtimeDebugViewModel: ObservableObject {
    @Published private(set) var rows: [SoundTransitRealtimeDebugRow] = []
    @Published private(set) var alertRows: [SoundTransitRealtimeDebugAlertRow] = []
    @Published private(set) var alertsCount = 0
    @Published private(set) var vehiclesCount = 0
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var loadedAt: Date?

    let agencyName: String

    private let provider: any RealtimeProvider
    private var loadTask: Task<Void, Never>?
    private lazy var loadedAtFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .medium
        return formatter
    }()

    init(
        agencyName: String = "Sound Transit",
        provider: any RealtimeProvider = SoundTransitRealtimeProvider()
    ) {
        self.agencyName = agencyName
        self.provider = provider
    }

    deinit {
        loadTask?.cancel()
    }

    var sections: [SoundTransitRealtimeDebugSection] {
        Dictionary(grouping: rows, by: \.routeId)
            .map { routeId, rows in
                SoundTransitRealtimeDebugSection(
                    routeId: routeId,
                    rows: rows.sorted(by: SoundTransitRealtimeDebugRow.sort)
                )
            }
            .sorted {
                $0.routeId.localizedStandardCompare($1.routeId) == .orderedAscending
            }
    }

    var summaryText: String {
        let loadedText = loadedAt.map { "updated \(loadedAtFormatter.string(from: $0))" } ?? "not loaded yet"
        return "\(rows.count) stop updates, \(alertsCount) alerts, \(vehiclesCount) vehicles, \(loadedText)"
    }

    func loadRealtimeData(forceRefresh: Bool = false) {
        if isLoading && !forceRefresh {
            return
        }

        loadTask?.cancel()
        loadTask = Task {
            isLoading = true
            defer { isLoading = false }

            do {
                async let tripUpdates = provider.tripUpdates()
                async let alerts = provider.alerts()
                async let vehicles = provider.vehiclePositions()

                rows = try await SoundTransitRealtimeDebugRow.rows(from: tripUpdates)
                alertRows = try await SoundTransitRealtimeDebugAlertRow.rows(from: alerts)
                alertsCount = alertRows.count
                vehiclesCount = try await vehicles.count
                loadedAt = Date()
                errorMessage = nil
            } catch {
                errorMessage = "Unable to load \(agencyName) realtime data: \(error.localizedDescription)"
            }
        }
    }
}

private struct SoundTransitRealtimeDebugAlertRow: Identifiable {
    let id: String
    let title: String
    let description: String?
    let routeIds: [String]
    let stopIds: [String]

    var routeText: String {
        routeIds.isEmpty ? "Routes: none scoped" : "Routes: \(routeIds.joined(separator: ", "))"
    }

    var stopText: String {
        stopIds.isEmpty ? "Stops: none scoped" : "Stops: \(stopIds.joined(separator: ", "))"
    }

    static func rows(from alerts: [RealtimeAlert]) -> [SoundTransitRealtimeDebugAlertRow] {
        alerts.map { alert in
            SoundTransitRealtimeDebugAlertRow(
                id: alert.id,
                title: alert.headerText ?? "Service alert",
                description: alert.descriptionText,
                routeIds: alert.routeIds.sorted(),
                stopIds: alert.stopIds.sorted()
            )
        }
        .sorted {
            $0.title.localizedStandardCompare($1.title) == .orderedAscending
        }
    }
}

private struct SoundTransitRealtimeDebugSection: Identifiable {
    let routeId: String
    let rows: [SoundTransitRealtimeDebugRow]

    var id: String { routeId }

    var title: String {
        "Route \(routeId)"
    }
}

private struct SoundTransitRealtimeDebugRow: Identifiable {
    let id: String
    let routeId: String
    let tripId: String
    let stopId: String
    let directionId: Int?
    let tripRelationship: String
    let stopRelationship: String
    let time: Date?
    let delay: TimeInterval?

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()

    var displayTime: String {
        guard let time else { return "No timestamp" }
        return Self.timeFormatter.string(from: time)
    }

    var directionText: String {
        directionId.map(String.init) ?? "unknown"
    }

    var delayText: String? {
        guard let delay else { return nil }

        if delay == 0 {
            return "on time"
        }

        let minutes = Int(abs(delay) / 60)
        let seconds = Int(abs(delay).truncatingRemainder(dividingBy: 60))
        let value = minutes > 0 ? "\(minutes)m \(seconds)s" : "\(seconds)s"
        return delay > 0 ? "\(value) late" : "\(value) early"
    }

    var delayIsLate: Bool {
        (delay ?? 0) > 0
    }

    static func rows(from tripUpdates: [RealtimeTripUpdate]) -> [SoundTransitRealtimeDebugRow] {
        tripUpdates.flatMap { tripUpdate in
            tripUpdate.stopTimeUpdates.enumerated().map { index, stopTimeUpdate in
                let time = stopTimeUpdate.arrivalTime ?? stopTimeUpdate.departureTime
                let delay = stopTimeUpdate.arrivalDelay ?? stopTimeUpdate.departureDelay
                let tripId = tripUpdate.tripId ?? "unknown-trip"
                let stopId = stopTimeUpdate.stopId ?? "unknown-stop"

                return SoundTransitRealtimeDebugRow(
                    id: "\(tripId)-\(stopId)-\(index)",
                    routeId: tripUpdate.routeId ?? "unknown-route",
                    tripId: tripId,
                    stopId: stopId,
                    directionId: tripUpdate.directionId,
                    tripRelationship: tripUpdate.scheduleRelationship.debugTitle,
                    stopRelationship: stopTimeUpdate.scheduleRelationship.debugTitle,
                    time: time,
                    delay: delay
                )
            }
        }
    }

    static func sort(_ lhs: SoundTransitRealtimeDebugRow, _ rhs: SoundTransitRealtimeDebugRow) -> Bool {
        switch (lhs.time, rhs.time) {
        case let (lhsTime?, rhsTime?):
            if lhsTime == rhsTime {
                return lhs.stopId.localizedStandardCompare(rhs.stopId) == .orderedAscending
            }
            return lhsTime < rhsTime
        case (_?, nil):
            return true
        case (nil, _?):
            return false
        case (nil, nil):
            return lhs.stopId.localizedStandardCompare(rhs.stopId) == .orderedAscending
        }
    }
}

private extension RealtimeTripScheduleRelationship {
    var debugTitle: String {
        switch self {
        case .scheduled:
            return "scheduled"
        case .added:
            return "added"
        case .unscheduled:
            return "unscheduled"
        case .canceled:
            return "canceled"
        case .replacement:
            return "replacement"
        case .duplicated:
            return "duplicated"
        case .unknown(let value):
            return "unknown \(value)"
        }
    }
}

private extension RealtimeStopScheduleRelationship {
    var debugTitle: String {
        switch self {
        case .scheduled:
            return "scheduled"
        case .skipped:
            return "skipped"
        case .noData:
            return "no data"
        case .unknown(let value):
            return "unknown \(value)"
        }
    }
}
#endif
