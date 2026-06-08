import Foundation

nonisolated struct StopDeparturesSection: Identifiable, Equatable, Sendable {
    let favorite: FavoriteStop
    let departures: [Departure]
    let alerts: [RealtimeAlert]

    init(favorite: FavoriteStop, departures: [Departure], alerts: [RealtimeAlert] = []) {
        self.favorite = favorite
        self.departures = departures
        self.alerts = alerts
    }

    var id: String { favorite.stopId }
}
