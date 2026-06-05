import Foundation

protocol TransitRepository: Sendable {
    func searchStops(query: String) async throws -> [TransitStop]
    func getDepartures(stopId: String) async throws -> [Departure]
}
