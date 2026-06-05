import Foundation

struct StopDeparturesSection: Identifiable, Equatable {
    let favorite: FavoriteStop
    let departures: [Departure]

    var id: String { favorite.stopId }
}
