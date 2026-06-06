import Combine
import Foundation

@MainActor
final class TransitBarViewModel: ObservableObject {
    @Published private(set) var favorites: [FavoriteStop]
    @Published private(set) var primaryStopId: String?
    @Published private(set) var departureSections: [StopDeparturesSection] = []
    @Published private(set) var lineResults: [TransitLine] = []
    @Published private(set) var selectedLine: TransitLine?
    @Published private(set) var lineStops: [TransitStop] = []
    @Published private(set) var isLoadingDepartures = false
    @Published private(set) var isSearching = false
    @Published private(set) var isLoadingLineStops = false
    @Published private(set) var errorMessage: String?
    @Published private var displayDate = Date()
    @Published var searchQuery = ""
    @Published var stopSearchFilter: StopSearchFilter = .all

    private let repository: TransitRepository
    private let settingsStore: UserSettingsStore
    private var refreshTask: Task<Void, Never>?
    private var displayClockTask: Task<Void, Never>?
    private var searchTask: Task<Void, Never>?

    init(repository: TransitRepository, settingsStore: UserSettingsStore = UserSettingsStore()) {
        self.repository = repository
        self.settingsStore = settingsStore
        self.favorites = settingsStore.favorites
        self.primaryStopId = settingsStore.primaryStopId
        ensurePrimaryStop()
        startRefreshTimer()
        startDisplayClock()
    }

    deinit {
        refreshTask?.cancel()
        displayClockTask?.cancel()
        searchTask?.cancel()
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
                errorMessage = "Unable to search stops."
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

        Task {
            isLoadingLineStops = true
            defer { isLoadingLineStops = false }

            do {
                lineStops = try await repository.getStops(lineId: line.id)
                errorMessage = nil
            } catch {
                lineStops = []
                errorMessage = "Unable to load stops."
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
    }

    func addFavorite(from stop: TransitStop) {
        guard !favorites.contains(where: { $0.stopId == stop.id }) else { return }

        favorites.append(FavoriteStop(stopId: stop.id, stopName: stop.name))
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

    func minutesText(for date: Date) -> String {
        let seconds = max(0, Int(date.timeIntervalSince(displayDate)))
        if seconds < 5 * 60 {
            let minutes = seconds / 60
            let remainingSeconds = seconds % 60

            if minutes == 0 {
                return "\(remainingSeconds)s"
            }

            return "\(minutes)m \(remainingSeconds)s"
        }

        return "\(seconds / 60)m"
    }

    func formattedDepartureLine(for departure: Departure) -> String {
        "\(departure.routeName) -> \(departure.destination)"
    }

    private func loadDepartures() async {
        guard !favorites.isEmpty else {
            departureSections = []
            errorMessage = nil
            return
        }

        isLoadingDepartures = true
        defer { isLoadingDepartures = false }

        do {
            var sections: [StopDeparturesSection] = []
            for favorite in favorites {
                let departures = try await repository.getDepartures(stopId: favorite.stopId)
                sections.append(StopDeparturesSection(favorite: favorite, departures: departures))
            }
            departureSections = sections
            errorMessage = nil
        } catch {
            departureSections = []
            errorMessage = "Unable to load departures."
        }
    }

    private func startRefreshTimer() {
        refreshTask?.cancel()
        refreshTask = Task {
            await loadDepartures()

            while !Task.isCancelled {
                let interval = settingsStore.refreshInterval
                try? await Task.sleep(for: .seconds(interval))
                await loadDepartures()
            }
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
        settingsStore.refreshInterval = 60
    }
}
