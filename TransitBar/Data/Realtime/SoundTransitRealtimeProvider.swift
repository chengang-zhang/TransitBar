import Foundation
import SwiftProtobuf

actor SoundTransitRealtimeProvider: RealtimeProvider {
    struct Configuration: Sendable {
        static let soundTransitAgencyId = "40"
        static let kingCountyMetroAgencyId = "1"
        static let defaultRefreshInterval: TimeInterval = 45
        static let soundTransit = Configuration(agencyId: soundTransitAgencyId)
        static let kingCountyMetro = Configuration(agencyId: kingCountyMetroAgencyId)

        let agencyId: String
        let tripUpdatesURL: URL
        let vehiclePositionsURL: URL
        let alertsURL: URL
        let refreshInterval: TimeInterval

        init(
            agencyId: String = Self.soundTransitAgencyId,
            tripUpdatesURL: URL? = nil,
            vehiclePositionsURL: URL? = nil,
            alertsURL: URL? = nil,
            refreshInterval: TimeInterval = Self.defaultRefreshInterval
        ) {
            self.agencyId = agencyId
            self.tripUpdatesURL = tripUpdatesURL ?? Self.feedURL(named: "trip-updates-for-agency", agencyId: agencyId)
            self.vehiclePositionsURL = vehiclePositionsURL ?? Self.feedURL(named: "vehicle-positions-for-agency", agencyId: agencyId)
            self.alertsURL = alertsURL ?? Self.feedURL(named: "alerts-for-agency", agencyId: agencyId)
            self.refreshInterval = refreshInterval
        }

        private static func feedURL(named feedName: String, agencyId: String) -> URL {
            URL(string: "https://api.pugetsound.onebusaway.org/api/gtfs_realtime/\(feedName)/\(agencyId).pb")!
        }
    }

    private let configuration: Configuration
    private let session: URLSession
    private var cachedTripUpdates: Cache<[RealtimeTripUpdate]>?
    private var cachedAlerts: Cache<[RealtimeAlert]>?
    private var cachedVehiclePositions: Cache<[RealtimeVehiclePosition]>?

    init(
        configuration: Configuration = Configuration(),
        session: URLSession = SoundTransitRealtimeProvider.makeSession()
    ) {
        self.configuration = configuration
        self.session = session
    }

    func tripUpdates() async throws -> [RealtimeTripUpdate] {
        if let cachedTripUpdates, !cachedTripUpdates.isExpired(refreshInterval: configuration.refreshInterval) {
            return cachedTripUpdates.value
        }

        do {
            let feed = try await fetchFeed(from: configuration.tripUpdatesURL)
            let updates = feed.entity.compactMap { entity -> RealtimeTripUpdate? in
                guard entity.hasTripUpdate else { return nil }
                return RealtimeTripUpdate(entity.tripUpdate)
            }
            cachedTripUpdates = Cache(value: updates, fetchedAt: Date())
            return updates
        } catch {
            if let cachedTripUpdates {
                return cachedTripUpdates.value
            }
            throw error
        }
    }

    func alerts() async throws -> [RealtimeAlert] {
        if let cachedAlerts, !cachedAlerts.isExpired(refreshInterval: configuration.refreshInterval) {
            return cachedAlerts.value
        }

        do {
            let feed = try await fetchFeed(from: configuration.alertsURL)
            let alerts = feed.entity.compactMap { entity -> RealtimeAlert? in
                guard entity.hasAlert else { return nil }
                return RealtimeAlert(id: entity.id, alert: entity.alert)
            }
            cachedAlerts = Cache(value: alerts, fetchedAt: Date())
            return alerts
        } catch {
            if let cachedAlerts {
                return cachedAlerts.value
            }
            throw error
        }
    }

    func vehiclePositions() async throws -> [RealtimeVehiclePosition] {
        if let cachedVehiclePositions, !cachedVehiclePositions.isExpired(refreshInterval: configuration.refreshInterval) {
            return cachedVehiclePositions.value
        }

        do {
            let feed = try await fetchFeed(from: configuration.vehiclePositionsURL)
            let positions = feed.entity.compactMap { entity -> RealtimeVehiclePosition? in
                guard entity.hasVehicle else { return nil }
                return RealtimeVehiclePosition(entity.vehicle)
            }
            cachedVehiclePositions = Cache(value: positions, fetchedAt: Date())
            return positions
        } catch {
            if let cachedVehiclePositions {
                return cachedVehiclePositions.value
            }
            throw error
        }
    }

    private func fetchFeed(from url: URL) async throws -> TransitRealtime_FeedMessage {
        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse,
              200..<300 ~= httpResponse.statusCode
        else {
            throw SoundTransitRealtimeError.invalidResponse
        }

        return try TransitRealtime_FeedMessage(serializedBytes: data)
    }

    private static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 10
        configuration.timeoutIntervalForResource = 15
        return URLSession(configuration: configuration)
    }
}

nonisolated private enum SoundTransitRealtimeError: Error {
    case invalidResponse
}

nonisolated private struct Cache<Value> {
    let value: Value
    let fetchedAt: Date

    func isExpired(refreshInterval: TimeInterval) -> Bool {
        Date().timeIntervalSince(fetchedAt) >= refreshInterval
    }
}

nonisolated private extension RealtimeTripUpdate {
    init(_ protobuf: TransitRealtime_TripUpdate) {
        self.init(
            tripId: protobuf.trip.hasTripID ? protobuf.trip.tripID : nil,
            routeId: protobuf.trip.hasRouteID ? protobuf.trip.routeID : nil,
            directionId: protobuf.trip.hasDirectionID ? Int(protobuf.trip.directionID) : nil,
            scheduleRelationship: RealtimeTripScheduleRelationship(protobuf.trip.scheduleRelationship),
            stopTimeUpdates: protobuf.stopTimeUpdate.map(RealtimeStopTimeUpdate.init)
        )
    }
}

nonisolated private extension RealtimeStopTimeUpdate {
    init(_ protobuf: TransitRealtime_TripUpdate.StopTimeUpdate) {
        let arrivalTime = protobuf.hasArrival && protobuf.arrival.hasTime
            ? Date(timeIntervalSince1970: TimeInterval(protobuf.arrival.time))
            : nil
        let departureTime = protobuf.hasDeparture && protobuf.departure.hasTime
            ? Date(timeIntervalSince1970: TimeInterval(protobuf.departure.time))
            : nil
        let arrivalDelay = protobuf.hasArrival && protobuf.arrival.hasDelay
            ? TimeInterval(protobuf.arrival.delay)
            : nil
        let departureDelay = protobuf.hasDeparture && protobuf.departure.hasDelay
            ? TimeInterval(protobuf.departure.delay)
            : nil

        self.init(
            stopId: protobuf.hasStopID ? protobuf.stopID : nil,
            arrivalTime: arrivalTime,
            departureTime: departureTime,
            arrivalDelay: arrivalDelay,
            departureDelay: departureDelay,
            scheduleRelationship: RealtimeStopScheduleRelationship(protobuf.scheduleRelationship)
        )
    }
}

nonisolated private extension RealtimeAlert {
    init(id: String, alert: TransitRealtime_Alert) {
        let routeIds = alert.informedEntity.compactMap { entity in
            entity.hasRouteID ? entity.routeID : nil
        }
        let stopIds = alert.informedEntity.compactMap { entity in
            entity.hasStopID ? entity.stopID : nil
        }

        self.init(
            id: id,
            routeIds: Set(routeIds),
            stopIds: Set(stopIds),
            headerText: alert.headerText.bestText,
            descriptionText: alert.descriptionText.bestText
        )
    }
}

nonisolated private extension RealtimeVehiclePosition {
    init(_ protobuf: TransitRealtime_VehiclePosition) {
        self.init(
            tripId: protobuf.hasTrip && protobuf.trip.hasTripID ? protobuf.trip.tripID : nil,
            vehicleId: protobuf.hasVehicle && protobuf.vehicle.hasID ? protobuf.vehicle.id : nil,
            timestamp: protobuf.hasTimestamp ? Date(timeIntervalSince1970: TimeInterval(protobuf.timestamp)) : nil
        )
    }
}

nonisolated private extension RealtimeTripScheduleRelationship {
    init(_ protobuf: TransitRealtime_TripDescriptor.ScheduleRelationship) {
        switch protobuf {
        case .scheduled:
            self = .scheduled
        case .added:
            self = .added
        case .unscheduled:
            self = .unscheduled
        case .canceled:
            self = .canceled
        case .replacement:
            self = .replacement
        case .duplicated:
            self = .duplicated
        case .UNRECOGNIZED(let value):
            self = .unknown(value)
        }
    }
}

nonisolated private extension RealtimeStopScheduleRelationship {
    init(_ protobuf: TransitRealtime_TripUpdate.StopTimeUpdate.ScheduleRelationship) {
        switch protobuf {
        case .scheduled:
            self = .scheduled
        case .skipped:
            self = .skipped
        case .noData:
            self = .noData
        case .UNRECOGNIZED(let value):
            self = .unknown(value)
        }
    }
}

nonisolated private extension TransitRealtime_TranslatedString {
    var bestText: String? {
        translation.first { $0.language.lowercased().hasPrefix("en") }?.text
            ?? translation.first?.text
    }
}
