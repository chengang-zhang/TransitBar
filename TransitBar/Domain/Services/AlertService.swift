import Foundation

nonisolated protocol AlertService: Sendable {
    func alerts(stopId: String, departures: [Departure]) async throws -> [RealtimeAlert]
}

nonisolated struct RealtimeAlertService: AlertService {
    let realtimeProvider: any RealtimeProvider
    let matcher: RealtimeAlertMatchingService

    init(
        realtimeProvider: any RealtimeProvider,
        matcher: RealtimeAlertMatchingService = RealtimeAlertMatchingService()
    ) {
        self.realtimeProvider = realtimeProvider
        self.matcher = matcher
    }

    func alerts(stopId: String, departures: [Departure]) async throws -> [RealtimeAlert] {
        let alerts = try await realtimeProvider.alerts()
        return matcher.matching(alerts: alerts, stopId: stopId, departures: departures)
    }
}

nonisolated struct RealtimeAlertMatchingService: Sendable {
    func matching(alerts: [RealtimeAlert], stopId: String, departures: [Departure]) -> [RealtimeAlert] {
        let normalizedStopId = normalizedId(stopId)
        let routeIds = Set(departures.compactMap(\.routeId).map(normalizedId))

        return alerts.filter { alert in
            let stopMatches = alert.stopIds
                .map(normalizedId)
                .contains(normalizedStopId)

            let routeMatches = !routeIds.isEmpty
                && !Set(alert.routeIds.map(normalizedId)).isDisjoint(with: routeIds)

            return stopMatches || routeMatches
        }
    }

    private func normalizedId(_ id: String) -> String {
        id.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
            .last
            .map(String.init) ?? id
    }
}
