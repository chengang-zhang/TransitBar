import Foundation

struct FailingTransitRepository: TransitRepository {
    let error: Error

    func searchStops(query: String) async throws -> [TransitStop] {
        throw error
    }

    func getDepartures(stopId: String) async throws -> [Departure] {
        throw error
    }
}
