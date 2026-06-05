import Foundation

struct FavoriteStop: Identifiable, Codable, Equatable, Sendable {
    var stopId: String
    var stopName: String
    var label: StopLabel?

    var id: String { stopId }
}
