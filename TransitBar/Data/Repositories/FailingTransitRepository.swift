import Foundation

nonisolated struct FailingTransitRepository: TransitRepository {
    let error: Error

    func searchLines(query: String, filter: StopSearchFilter) async throws -> [TransitLine] {
        throw error
    }

    func getStops(lineId: String) async throws -> [TransitStop] {
        throw error
    }

    func getDepartures(stopId: String) async throws -> [Departure] {
        throw error
    }
}
