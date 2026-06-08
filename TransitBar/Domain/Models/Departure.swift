import Foundation

nonisolated struct Departure: Identifiable, Equatable, Sendable {
    let id: String
    let tripId: String?
    let stopId: String?
    let routeId: String?
    let routeName: String
    let destination: String
    let departureTime: Date
    let scheduledTime: Date
    let routeColorHex: String?
    let routeTextColorHex: String?
    let routeType: Int?
    let predictionSource: ArrivalPredictionSource

    init(
        id: String = UUID().uuidString,
        tripId: String? = nil,
        stopId: String? = nil,
        routeId: String? = nil,
        routeName: String,
        destination: String,
        departureTime: Date,
        scheduledTime: Date? = nil,
        routeColorHex: String? = nil,
        routeTextColorHex: String? = nil,
        routeType: Int? = nil,
        predictionSource: ArrivalPredictionSource = .scheduled
    ) {
        self.id = id
        self.tripId = tripId
        self.stopId = stopId
        self.routeId = routeId
        self.routeName = routeName
        self.destination = destination
        self.departureTime = departureTime
        self.scheduledTime = scheduledTime ?? departureTime
        self.routeColorHex = routeColorHex
        self.routeTextColorHex = routeTextColorHex
        self.routeType = routeType
        self.predictionSource = predictionSource
    }

    var isRealtime: Bool {
        predictionSource == .realtime
    }

    var isCanceled: Bool {
        predictionSource == .canceled || predictionSource == .skipped
    }

    func applyingRealtime(
        departureTime: Date,
        predictionSource: ArrivalPredictionSource
    ) -> Departure {
        Departure(
            id: id,
            tripId: tripId,
            stopId: stopId,
            routeId: routeId,
            routeName: routeName,
            destination: destination,
            departureTime: departureTime,
            scheduledTime: scheduledTime,
            routeColorHex: routeColorHex,
            routeTextColorHex: routeTextColorHex,
            routeType: routeType,
            predictionSource: predictionSource
        )
    }
}

nonisolated enum ArrivalPredictionSource: String, Sendable {
    case scheduled
    case realtime
    case canceled
    case skipped

    var displayTitle: String {
        switch self {
        case .scheduled:
            return "Scheduled"
        case .realtime:
            return "Live"
        case .canceled:
            return "Canceled"
        case .skipped:
            return "Skipped"
        }
    }
}
