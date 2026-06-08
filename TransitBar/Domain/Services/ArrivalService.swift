nonisolated protocol ArrivalService: Sendable {
    func getDepartures(stopId: String) async throws -> [Departure]
}

nonisolated struct StaticArrivalService: ArrivalService {
    let repository: any TransitRepository

    func getDepartures(stopId: String) async throws -> [Departure] {
        try await repository.getDepartures(stopId: stopId)
    }
}

nonisolated struct RealtimeOverlayArrivalService: ArrivalService {
    let staticArrivalService: any ArrivalService
    let realtimeProvider: any RealtimeProvider
    let overlayService: RealtimeArrivalOverlayService

    init(
        staticArrivalService: any ArrivalService,
        realtimeProvider: any RealtimeProvider,
        overlayService: RealtimeArrivalOverlayService = RealtimeArrivalOverlayService()
    ) {
        self.staticArrivalService = staticArrivalService
        self.realtimeProvider = realtimeProvider
        self.overlayService = overlayService
    }

    func getDepartures(stopId: String) async throws -> [Departure] {
        let staticDepartures = try await staticArrivalService.getDepartures(stopId: stopId)

        do {
            let tripUpdates = try await realtimeProvider.tripUpdates()
            return overlayService.overlay(staticDepartures: staticDepartures, tripUpdates: tripUpdates)
        } catch {
            return staticDepartures
        }
    }
}
