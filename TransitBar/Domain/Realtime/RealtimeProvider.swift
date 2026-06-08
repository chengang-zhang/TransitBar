nonisolated protocol RealtimeProvider: Sendable {
    func tripUpdates() async throws -> [RealtimeTripUpdate]
    func alerts() async throws -> [RealtimeAlert]
    func vehiclePositions() async throws -> [RealtimeVehiclePosition]
}
