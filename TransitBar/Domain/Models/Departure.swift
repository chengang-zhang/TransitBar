import Foundation

struct Departure: Identifiable, Equatable, Sendable {
    let id: String
    let routeName: String
    let destination: String
    let departureTime: Date
    let routeColorHex: String?
    let routeTextColorHex: String?
    let routeType: Int?

    init(
        id: String = UUID().uuidString,
        routeName: String,
        destination: String,
        departureTime: Date,
        routeColorHex: String? = nil,
        routeTextColorHex: String? = nil,
        routeType: Int? = nil
    ) {
        self.id = id
        self.routeName = routeName
        self.destination = destination
        self.departureTime = departureTime
        self.routeColorHex = routeColorHex
        self.routeTextColorHex = routeTextColorHex
        self.routeType = routeType
    }
}
