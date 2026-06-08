import Foundation

nonisolated enum RealtimeTripScheduleRelationship: Equatable, Sendable {
    case scheduled
    case added
    case unscheduled
    case canceled
    case replacement
    case duplicated
    case unknown(Int)
}

nonisolated enum RealtimeStopScheduleRelationship: Equatable, Sendable {
    case scheduled
    case skipped
    case noData
    case unknown(Int)
}

nonisolated struct RealtimeStopTimeUpdate: Equatable, Sendable {
    let stopId: String?
    let arrivalTime: Date?
    let departureTime: Date?
    let arrivalDelay: TimeInterval?
    let departureDelay: TimeInterval?
    let scheduleRelationship: RealtimeStopScheduleRelationship

    init(
        stopId: String?,
        arrivalTime: Date? = nil,
        departureTime: Date? = nil,
        arrivalDelay: TimeInterval? = nil,
        departureDelay: TimeInterval? = nil,
        scheduleRelationship: RealtimeStopScheduleRelationship = .scheduled
    ) {
        self.stopId = stopId
        self.arrivalTime = arrivalTime
        self.departureTime = departureTime
        self.arrivalDelay = arrivalDelay
        self.departureDelay = departureDelay
        self.scheduleRelationship = scheduleRelationship
    }
}

nonisolated struct RealtimeTripUpdate: Equatable, Sendable {
    let tripId: String?
    let routeId: String?
    let directionId: Int?
    let scheduleRelationship: RealtimeTripScheduleRelationship
    let stopTimeUpdates: [RealtimeStopTimeUpdate]

    init(
        tripId: String?,
        routeId: String? = nil,
        directionId: Int? = nil,
        scheduleRelationship: RealtimeTripScheduleRelationship = .scheduled,
        stopTimeUpdates: [RealtimeStopTimeUpdate]
    ) {
        self.tripId = tripId
        self.routeId = routeId
        self.directionId = directionId
        self.scheduleRelationship = scheduleRelationship
        self.stopTimeUpdates = stopTimeUpdates
    }
}

nonisolated struct RealtimeAlert: Equatable, Sendable {
    let id: String
    let routeIds: Set<String>
    let stopIds: Set<String>
    let headerText: String?
    let descriptionText: String?
}

nonisolated struct RealtimeVehiclePosition: Equatable, Sendable {
    let tripId: String?
    let vehicleId: String?
    let timestamp: Date?
}
