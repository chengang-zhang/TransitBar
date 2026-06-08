nonisolated struct RealtimeOverlayTransitRepository: TransitRepository {
    let baseRepository: any TransitRepository
    let arrivalService: any ArrivalService

    func searchLines(query: String, filter: StopSearchFilter) async throws -> [TransitLine] {
        try await baseRepository.searchLines(query: query, filter: filter)
    }

    func getStops(lineId: String) async throws -> [TransitStop] {
        try await baseRepository.getStops(lineId: lineId)
    }

    func getDepartures(stopId: String) async throws -> [Departure] {
        try await arrivalService.getDepartures(stopId: stopId)
    }
}
