import Combine
import Foundation

@MainActor
final class TransitBarViewModel: ObservableObject {
    @Published private(set) var favorites: [FavoriteStop]
    @Published private(set) var primaryStopId: String?
    @Published private(set) var departureSections: [StopDeparturesSection] = []
    @Published private(set) var lineResults: [TransitLine] = []
    @Published private(set) var selectedLine: TransitLine?
    @Published private(set) var selectedLineStop: TransitStop?
    @Published private(set) var lineStops: [TransitStop] = []
    @Published private(set) var selectedLineStopDepartures: [Departure] = []
    @Published private(set) var isLoadingDepartures = false
    @Published private(set) var isSearching = false
    @Published private(set) var isLoadingLineStops = false
    @Published private(set) var isLoadingLineStopDepartures = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var refreshInterval: TimeInterval
    @Published private(set) var showsSecondsForNearDepartures: Bool
    @Published private(set) var maxDeparturesPerStop: Int
    @Published private var displayDate = Date()
    @Published var searchQuery = ""
    @Published var stopSearchFilter: StopSearchFilter = .all

    private let repository: any TransitRepository
    private let alertService: (any AlertService)?
    private let settingsStore: UserSettingsStore
    private var refreshTask: Task<Void, Never>?
    private var displayClockTask: Task<Void, Never>?
    private var searchTask: Task<Void, Never>?
    private var lineStopDeparturesTask: Task<Void, Never>?
    private lazy var sameDayDepartureFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()
    private lazy var futureDayDepartureFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("EEE h:mm a")
        return formatter
    }()

    init(
        repository: any TransitRepository,
        alertService: (any AlertService)? = nil,
        settingsStore: UserSettingsStore = UserSettingsStore()
    ) {
        self.repository = repository
        self.alertService = alertService
        self.settingsStore = settingsStore
        self.favorites = settingsStore.favorites
        self.primaryStopId = settingsStore.primaryStopId
        self.refreshInterval = settingsStore.refreshInterval
        self.showsSecondsForNearDepartures = settingsStore.showsSecondsForNearDepartures
        self.maxDeparturesPerStop = settingsStore.maxDeparturesPerStop
        ensurePrimaryStop()
        startRefreshTimer()
        startDisplayClock()
    }

    deinit {
        refreshTask?.cancel()
        displayClockTask?.cancel()
        searchTask?.cancel()
        lineStopDeparturesTask?.cancel()
    }

    var menuBarTitle: String {
        guard !favorites.isEmpty else { return "TransitBar" }
        guard let departure = primaryDeparture else {
            return "No Departures"
        }

        return "\(departure.routeName) \(minutesText(for: departure.departureTime))"
    }

    var primaryDeparture: Departure? {
        guard
            let primaryStopId,
            let section = departureSections.first(where: { $0.favorite.stopId == primaryStopId })
        else {
            return nil
        }

        return section.departures.first
    }

    var primaryStopName: String? {
        favorites.first { $0.stopId == primaryStopId }?.stopName
    }

    func refreshDepartures() {
        Task { await loadDepartures() }
    }

    func searchLines() {
        let query = searchQuery
        let filter = stopSearchFilter
        searchTask?.cancel()

        searchTask = Task {
            isSearching = true
            defer { isSearching = false }

            do {
                lineResults = try await repository.searchLines(query: query, filter: filter)
                errorMessage = nil
            } catch {
                lineResults = []
                errorMessage = "Unable to load routes: \(error.localizedDescription)"
            }
        }
    }

    func scheduleLineSearch(clearingSelection: Bool = false) {
        Task { @MainActor in
            if clearingSelection {
                clearSelectedLine()
            }
            searchLines()
        }
    }

    func selectLine(_ line: TransitLine) {
        selectedLine = line
        lineStops = []
        clearSelectedLineStop()
        isLoadingLineStops = true

        Task {
            defer { isLoadingLineStops = false }

            do {
                lineStops = try await repository.getStops(lineId: line.id)
                errorMessage = nil
            } catch {
                lineStops = []
                errorMessage = "Unable to load stops: \(error.localizedDescription)"
            }
        }
    }

    func selectLineStop(_ stop: TransitStop) {
        if selectedLineStop?.id == stop.id {
            clearSelectedLineStop()
            return
        }

        selectedLineStop = stop
        selectedLineStopDepartures = []
        isLoadingLineStopDepartures = true
        lineStopDeparturesTask?.cancel()

        let stopId = stop.id
        lineStopDeparturesTask = Task {
            defer {
                if selectedLineStop?.id == stopId {
                    isLoadingLineStopDepartures = false
                }
            }

            do {
                let departures = try await repository.getDepartures(stopId: stopId)
                guard selectedLineStop?.id == stopId else { return }
                selectedLineStopDepartures = departures
                errorMessage = nil
            } catch {
                guard selectedLineStop?.id == stopId else { return }
                selectedLineStopDepartures = []
                errorMessage = "Unable to load arrivals: \(error.localizedDescription)"
            }
        }
    }

    func clearSelectedLine() {
        if selectedLine != nil {
            selectedLine = nil
        }
        if !lineStops.isEmpty {
            lineStops = []
        }
        clearSelectedLineStop()
    }

    private func clearSelectedLineStop() {
        lineStopDeparturesTask?.cancel()
        if selectedLineStop != nil {
            selectedLineStop = nil
        }
        if !selectedLineStopDepartures.isEmpty {
            selectedLineStopDepartures = []
        }
        isLoadingLineStopDepartures = false
    }

    func addFavorite(from stop: TransitStop) {
        guard !favorites.contains(where: { $0.stopId == stop.id }) else { return }

        favorites.append(FavoriteStop(stopId: stop.id, stopName: stop.favoriteName))
        ensurePrimaryStop()
        persistFavorites()
        refreshDepartures()
    }

    func removeFavorite(_ favorite: FavoriteStop) {
        favorites.removeAll { $0.stopId == favorite.stopId }
        if primaryStopId == favorite.stopId {
            primaryStopId = favorites.first?.stopId
        }
        persistFavorites()
        refreshDepartures()
    }

    func setPrimaryStop(_ favorite: FavoriteStop) {
        primaryStopId = favorite.stopId
        persistFavorites()
        refreshDepartures()
    }

    func isFavorite(_ stop: TransitStop) -> Bool {
        favorites.contains { $0.stopId == stop.id }
    }

    func isPrimary(_ favorite: FavoriteStop) -> Bool {
        favorite.stopId == primaryStopId
    }

    func setRefreshInterval(_ interval: TimeInterval) {
        refreshInterval = interval
        settingsStore.refreshInterval = interval
        startRefreshTimer()
    }

    func setShowsSecondsForNearDepartures(_ showsSeconds: Bool) {
        showsSecondsForNearDepartures = showsSeconds
        settingsStore.showsSecondsForNearDepartures = showsSeconds
    }

    func setMaxDeparturesPerStop(_ count: Int) {
        maxDeparturesPerStop = max(1, min(count, 12))
        settingsStore.maxDeparturesPerStop = maxDeparturesPerStop
    }

    func minutesText(for date: Date) -> String {
        let seconds = max(0, Int(date.timeIntervalSince(displayDate)))
        if seconds < 5 * 60 {
            guard showsSecondsForNearDepartures else {
                return "\(max(1, (seconds + 59) / 60))m"
            }

            let minutes = seconds / 60
            let remainingSeconds = seconds % 60

            if minutes == 0 {
                return "\(remainingSeconds)s"
            }

            return "\(minutes)m \(remainingSeconds)s"
        }

        if seconds > 60 * 60 {
            if Calendar.current.isDate(date, inSameDayAs: displayDate) {
                return sameDayDepartureFormatter.string(from: date)
            }

            return futureDayDepartureFormatter.string(from: date)
        }

        return "\(seconds / 60)m"
    }

    func departureTimeText(for date: Date) -> String {
        let text = minutesText(for: date)
        let seconds = max(0, Int(date.timeIntervalSince(displayDate)))
        return seconds > 60 * 60 ? "at \(text)" : text
    }

    func formattedDepartureLine(for departure: Departure) -> String {
        "\(departure.routeName) -> \(departure.destination)"
    }

    func alertTitle(for section: StopDeparturesSection) -> String {
        let count = section.alerts.count
        return count == 1 ? "1 service alert" : "\(count) service alerts"
    }

    private func loadDepartures() async {
        guard !favorites.isEmpty else {
            departureSections = []
            errorMessage = nil
            return
        }

        isLoadingDepartures = true
        defer { isLoadingDepartures = false }

        let favorites = favorites
        let repository = repository
        let alertService = alertService
        let sections = await withTaskGroup(of: (Int, StopDeparturesSection, Error?).self) { group in
            for (index, favorite) in favorites.enumerated() {
                group.addTask {
                    do {
                        let departures = try await repository.getDepartures(stopId: favorite.stopId)
                        let alerts: [RealtimeAlert]
                        if let alertService {
                            alerts = (try? await alertService.alerts(stopId: favorite.stopId, departures: departures)) ?? []
                        } else {
                            alerts = []
                        }
                        return (index, StopDeparturesSection(favorite: favorite, departures: departures, alerts: alerts), nil)
                    } catch {
                        return (index, StopDeparturesSection(favorite: favorite, departures: []), error)
                    }
                }
            }

            var sections: [(Int, StopDeparturesSection, Error?)] = []
            for await section in group {
                sections.append(section)
            }
            return sections
                .sorted { $0.0 < $1.0 }
                .map { ($0.1, $0.2) }
        }
        departureSections = sections.map(\.0)
        errorMessage = sections.contains { $0.1 != nil } ? "Some departures could not be loaded." : nil
    }

    private func startRefreshTimer() {
        refreshTask?.cancel()
        refreshTask = Task {
            await loadDepartures()

            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(refreshInterval))
                await loadDepartures()
            }
        }
    }

    private func alerts(for stopId: String, departures: [Departure]) async -> [RealtimeAlert] {
        guard let alertService else { return [] }

        do {
            return try await alertService.alerts(stopId: stopId, departures: departures)
        } catch {
            return []
        }
    }

    private func startDisplayClock() {
        displayClockTask?.cancel()
        displayClockTask = Task {
            while !Task.isCancelled {
                displayDate = Date()
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    private func ensurePrimaryStop() {
        if let primaryStopId, favorites.contains(where: { $0.stopId == primaryStopId }) {
            return
        }
        primaryStopId = favorites.first?.stopId
    }

    private func persistFavorites() {
        settingsStore.favorites = favorites
        settingsStore.primaryStopId = primaryStopId
    }
}
