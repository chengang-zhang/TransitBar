import Foundation

nonisolated struct RealtimeArrivalOverlayService: Sendable {
    func overlay(
        staticDepartures: [Departure],
        tripUpdates: [RealtimeTripUpdate]
    ) -> [Departure] {
        let updatesByKey = realtimeUpdatesByTripAndStop(tripUpdates)

        return staticDepartures.map { departure in
            guard
                let tripId = departure.tripId,
                let stopId = departure.stopId,
                let update = updatesByKey[RealtimeArrivalKey(tripId: tripId, stopId: stopId)]
            else {
                return departure
            }

            switch update.status {
            case .canceled:
                return departure.applyingRealtime(
                    departureTime: departure.departureTime,
                    predictionSource: .canceled
                )
            case .skipped:
                return departure.applyingRealtime(
                    departureTime: departure.departureTime,
                    predictionSource: .skipped
                )
            case .active:
                let predictedTime = update.predictedTime(for: departure)

                return departure.applyingRealtime(
                    departureTime: predictedTime,
                    predictionSource: .realtime
                )
            }
        }
        .sorted { lhs, rhs in
            if lhs.isCanceled != rhs.isCanceled {
                return !lhs.isCanceled
            }
            return lhs.departureTime < rhs.departureTime
        }
    }

    private func realtimeUpdatesByTripAndStop(_ tripUpdates: [RealtimeTripUpdate]) -> [RealtimeArrivalKey: RealtimeArrivalUpdate] {
        var updates: [RealtimeArrivalKey: RealtimeArrivalUpdate] = [:]

        for tripUpdate in tripUpdates {
            guard let tripId = tripUpdate.tripId else { continue }

            for stopTimeUpdate in tripUpdate.stopTimeUpdates {
                guard let stopId = stopTimeUpdate.stopId else { continue }

                let key = RealtimeArrivalKey(tripId: tripId, stopId: stopId)
                if tripUpdate.scheduleRelationship == .canceled {
                    updates[key] = RealtimeArrivalUpdate(status: .canceled)
                    continue
                }

                if stopTimeUpdate.scheduleRelationship == .skipped {
                    updates[key] = RealtimeArrivalUpdate(status: .skipped)
                    continue
                }

                updates[key] = RealtimeArrivalUpdate(
                    status: .active,
                    explicitTime: stopTimeUpdate.arrivalTime ?? stopTimeUpdate.departureTime,
                    delay: stopTimeUpdate.arrivalDelay ?? stopTimeUpdate.departureDelay
                )
            }
        }

        return updates
    }
}

nonisolated private struct RealtimeArrivalKey: Hashable {
    let tripId: String
    let stopId: String

    init(tripId: String, stopId: String) {
        self.tripId = Self.normalizedId(tripId)
        self.stopId = Self.normalizedId(stopId)
    }

    private static func normalizedId(_ id: String) -> String {
        id.split(separator: ":", maxSplits: 1).last.map(String.init) ?? id
    }
}

nonisolated private struct RealtimeArrivalUpdate {
    enum Status {
        case active
        case canceled
        case skipped
    }

    let status: Status
    let explicitTime: Date?
    let delay: TimeInterval?

    init(status: Status, explicitTime: Date? = nil, delay: TimeInterval? = nil) {
        self.status = status
        self.explicitTime = explicitTime
        self.delay = delay
    }

    func predictedTime(for departure: Departure) -> Date {
        if let explicitTime {
            return explicitTime
        }

        if let delay {
            return departure.scheduledTime.addingTimeInterval(delay)
        }

        return departure.departureTime
    }
}
