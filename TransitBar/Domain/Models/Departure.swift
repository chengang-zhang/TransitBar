import Foundation

struct Departure: Identifiable, Equatable, Sendable {
    let id: String
    let routeName: String
    let destination: String
    let departureTime: Date

    init(
        id: String = UUID().uuidString,
        routeName: String,
        destination: String,
        departureTime: Date
    ) {
        self.id = id
        self.routeName = routeName
        self.destination = destination
        self.departureTime = departureTime
    }
}
