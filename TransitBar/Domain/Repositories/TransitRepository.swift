import Foundation

protocol TransitRepository: Sendable {
    func searchLines(query: String, filter: StopSearchFilter) async throws -> [TransitLine]
    func getStops(lineId: String) async throws -> [TransitStop]
    func getDepartures(stopId: String) async throws -> [Departure]
}
