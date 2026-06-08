import Foundation

nonisolated final class StaticGtfsTransitRepository: TransitRepository, @unchecked Sendable {
    private let schedule: GTFSSchedule
    private let calendar: Calendar
    private let horizon: TimeInterval
    private let fallbackHorizon: TimeInterval
    private let legacyDefaultFeedId = "sound-transit"

    init(
        bundle: Bundle = .main,
        gtfsFeeds: [GTFSFeedResource] = GTFSFeedResource.defaultFeeds,
        calendar: Calendar = .current,
        horizon: TimeInterval = 6 * 60 * 60,
        fallbackHorizon: TimeInterval = 36 * 60 * 60
    ) throws {
        let parser = GTFSParser(calendar: calendar)
        let schedules = try gtfsFeeds.map { feed in
            guard let url = bundle.url(forResource: feed.resourceName, withExtension: feed.resourceExtension) else {
                throw GTFSParserError.missingFile(feed.directoryName)
            }

            return try parser.parse(directoryURL: url, feedId: feed.id, feedName: feed.displayName)
        }

        self.schedule = GTFSSchedule.merging(schedules)
        self.calendar = calendar
        self.horizon = horizon
        self.fallbackHorizon = fallbackHorizon
    }

    init(
        schedule: GTFSSchedule,
        calendar: Calendar = .current,
        horizon: TimeInterval = 6 * 60 * 60,
        fallbackHorizon: TimeInterval = 36 * 60 * 60
    ) {
        self.schedule = schedule
        self.calendar = calendar
        self.horizon = horizon
        self.fallbackHorizon = fallbackHorizon
    }

    func searchLines(query: String, filter: StopSearchFilter) async throws -> [TransitLine] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)

        let matchingRoutes = schedule.routes.values
            .filter { route in
                includes(route, filter: filter)
                    && (
                        trimmedQuery.isEmpty
                            || route.displayName.localizedCaseInsensitiveContains(trimmedQuery)
                            || route.longName.localizedCaseInsensitiveContains(trimmedQuery)
                            || route.routeDescription.localizedCaseInsensitiveContains(trimmedQuery)
                    )
            }
            .sorted { lhs, rhs in
                let lhsSortKey = lineSortKey(lhs)
                let rhsSortKey = lineSortKey(rhs)
                if lhsSortKey != rhsSortKey {
                    return lhsSortKey.localizedStandardCompare(rhsSortKey) == .orderedAscending
                }
                return lhs.id.localizedStandardCompare(rhs.id) == .orderedAscending
            }

        return deduplicatedRoutes(matchingRoutes).map { route in
            TransitLine(
                id: route.id,
                sourceId: route.feedId,
                sourceName: route.feedName,
                name: route.displayName,
                details: route.longName.isEmpty ? route.routeDescription : route.longName,
                routeColorHex: route.colorHex,
                routeTextColorHex: route.textColorHex,
                routeType: route.routeType
            )
        }
    }

    func getStops(lineId: String) async throws -> [TransitStop] {
        let routeId = normalizedRouteId(lineId)
        let orderedStops = representativeStopIds(for: routeId).compactMap { stopId -> GTFSStop? in
            guard let stop = schedule.stops[stopId],
                  schedule.stopTimesByStopId[stop.id] != nil,
                  stop.locationType != 1,
                  stop.locationType != 2
            else { return nil }

            return stop
        }

        let duplicateDisplayNames = Set(
            Dictionary(grouping: orderedStops, by: \.searchDisplayName)
                .filter { $0.value.count > 1 }
                .keys
        )

        return orderedStops.map { stop in
            TransitStop(
                id: stop.id,
                name: duplicateDisplayNames.contains(stop.searchDisplayName)
                    ? stop.disambiguatedSearchDisplayName
                    : stop.searchDisplayName
            )
        }
    }

    private func representativeStopIds(for routeId: String) -> [String] {
        let routeTrips = trips(for: routeId)
        guard !routeTrips.isEmpty else { return [] }

        var patterns: [String: StopPattern] = [:]

        for trip in routeTrips {
            let stopIds = orderedStopIds(for: trip.id)
            guard !stopIds.isEmpty else { continue }

            let key = stopIds.joined(separator: "\u{1f}")
            if var pattern = patterns[key] {
                pattern.tripCount += 1
                patterns[key] = pattern
            } else {
                patterns[key] = StopPattern(stopIds: stopIds, tripCount: 1)
            }
        }

        return patterns.values.sorted { lhs, rhs in
            if lhs.stopIds.count != rhs.stopIds.count { return lhs.stopIds.count > rhs.stopIds.count }
            if lhs.tripCount != rhs.tripCount { return lhs.tripCount > rhs.tripCount }
            return lhs.stopIds.joined(separator: "\u{1f}") < rhs.stopIds.joined(separator: "\u{1f}")
        }
        .first?
        .stopIds ?? []
    }

    private func orderedStopIds(for tripId: String) -> [String] {
        var seenStopIds = Set<String>()

        return (schedule.stopTimesByTripId[tripId] ?? []).compactMap { stopTime in
            guard seenStopIds.insert(stopTime.stopId).inserted else { return nil }
            return stopTime.stopId
        }
    }

    func getDepartures(stopId: String) async throws -> [Departure] {
        upcomingDepartures(stopId: normalizedStopId(stopId), at: Date())
    }

    func upcomingDepartures(stopId: String, at now: Date) -> [Departure] {
        let stopTimes = schedule.stopTimesByStopId[stopId] ?? []
        let departures = upcomingDepartures(from: stopTimes, at: now, horizon: horizon)

        if !departures.isEmpty {
            return departures
        }

        return Array(upcomingDepartures(from: stopTimes, at: now, horizon: fallbackHorizon).prefix(1))
    }

    private func upcomingDepartures(from stopTimes: [GTFSStopTime], at now: Date, horizon: TimeInterval) -> [Departure] {
        let todayStart = calendar.startOfDay(for: now)
        let end = now.addingTimeInterval(horizon)
        let maxDayOffset = max(1, Int(ceil(horizon / (24 * 60 * 60))) + 1)

        return (-1...maxDayOffset).flatMap { dayOffset in
            departures(
                from: stopTimes,
                serviceDate: calendar.date(byAdding: .day, value: dayOffset, to: todayStart) ?? todayStart,
                now: now,
                end: end
            )
        }
        .sorted { $0.departureTime < $1.departureTime }
        .prefix(12)
        .map { $0 }
    }

    private func departures(
        from stopTimes: [GTFSStopTime],
        serviceDate: Date,
        now: Date,
        end: Date
    ) -> [Departure] {
        stopTimes.compactMap { stopTime in
            guard
                let trip = schedule.trips[stopTime.tripId],
                isServiceActive(serviceId: trip.serviceId, on: serviceDate)
            else { return nil }

            let departureDate = serviceDate.addingTimeInterval(TimeInterval(stopTime.departureSeconds))
            guard departureDate >= now, departureDate <= end else { return nil }

            let route = schedule.routes[trip.routeId]
            let destination = trip.headsign.isEmpty ? (route?.longName ?? "") : trip.headsign

            return Departure(
                id: "\(stopTime.tripId)-\(stopTime.stopId)-\(Int(departureDate.timeIntervalSince1970))",
                tripId: stopTime.tripId,
                stopId: stopTime.stopId,
                routeId: trip.routeId,
                routeName: route?.displayName ?? trip.routeId,
                destination: destination,
                departureTime: departureDate,
                scheduledTime: departureDate,
                routeColorHex: route?.colorHex,
                routeTextColorHex: route?.textColorHex,
                routeType: route?.routeType
            )
        }
    }

    private func isServiceActive(serviceId: String, on serviceDate: Date) -> Bool {
        let key = GTFSTime.serviceDateKey(for: serviceDate, calendar: calendar)
        if let exception = schedule.calendarDates[serviceId]?[key] {
            return exception.exceptionType == 1
        }

        guard let service = schedule.calendars[serviceId] else { return false }

        let day = calendar.startOfDay(for: serviceDate)
        guard day >= service.startDate, day <= service.endDate else { return false }

        let weekday = calendar.component(.weekday, from: day)
        return service.activeWeekdays.contains(weekday)
    }

    private func normalizedStopId(_ stopId: String) -> String {
        if schedule.stops[stopId] != nil {
            return stopId
        }

        let migratedStopId = "\(legacyDefaultFeedId):\(stopId)"
        return schedule.stops[migratedStopId] == nil ? stopId : migratedStopId
    }

    private func normalizedRouteId(_ routeId: String) -> String {
        if schedule.routes[routeId] != nil {
            return routeId
        }

        let migratedRouteId = "\(legacyDefaultFeedId):\(routeId)"
        return schedule.routes[migratedRouteId] == nil ? routeId : migratedRouteId
    }

    private func trips(for routeId: String) -> [GTFSTrip] {
        schedule.trips.values.filter { $0.routeId == routeId }
    }

    private func lineSortKey(_ route: GTFSRoute) -> String {
        "\(routeTypeRank(route.routeType))-\(route.displayName)"
    }

    private func includes(_ route: GTFSRoute, filter: StopSearchFilter) -> Bool {
        filter.includes(routeType: route.routeType)
    }

    private func routeTypeRank(_ routeType: Int?) -> String {
        switch routeType {
        case 0, 1, 2:
            return "0"
        case 3:
            return "1"
        case 4:
            return "2"
        default:
            return "3"
        }
    }

    private func deduplicatedRoutes(_ routes: [GTFSRoute]) -> [GTFSRoute] {
        var seenKeys = Set<String>()

        return routes.filter { route in
            let key = [
                route.feedName,
                route.displayName,
                route.longName,
                route.routeDescription,
                route.routeType.map(String.init) ?? ""
            ].joined(separator: "\u{1f}")

            return seenKeys.insert(key).inserted
        }
    }
}

actor LazyStaticGtfsTransitRepository: TransitRepository {
    private var repository: StaticGtfsTransitRepository?

    func searchLines(query: String, filter: StopSearchFilter) async throws -> [TransitLine] {
        let repository = try loadedRepository()
        return try await repository.searchLines(query: query, filter: filter)
    }

    func getStops(lineId: String) async throws -> [TransitStop] {
        let repository = try loadedRepository()
        return try await repository.getStops(lineId: lineId)
    }

    func getDepartures(stopId: String) async throws -> [Departure] {
        let repository = try loadedRepository()
        return try await repository.getDepartures(stopId: stopId)
    }

    private func loadedRepository() throws -> StaticGtfsTransitRepository {
        if let repository {
            return repository
        }

        let repository = try StaticGtfsTransitRepository()
        self.repository = repository
        return repository
    }
}

private struct StopPattern {
    let stopIds: [String]
    var tripCount: Int
}

nonisolated struct GTFSFeedResource: Sendable {
    let id: String
    let directoryName: String
    let displayName: String

    var resourceName: String {
        (directoryName as NSString).deletingPathExtension
    }

    var resourceExtension: String? {
        let pathExtension = (directoryName as NSString).pathExtension
        return pathExtension.isEmpty ? nil : pathExtension
    }

    static let defaultFeeds = [
        GTFSFeedResource(id: "puget-sound", directoryName: "Puget Sound.bundle", displayName: "Puget Sound")
    ]
}

nonisolated extension GTFSSchedule {
    static func merging(_ schedules: [GTFSSchedule]) -> GTFSSchedule {
        GTFSSchedule(
            stops: schedules.reduce(into: [:]) { $0.merge($1.stops) { current, _ in current } },
            routes: schedules.reduce(into: [:]) { $0.merge($1.routes) { current, _ in current } },
            trips: schedules.reduce(into: [:]) { $0.merge($1.trips) { current, _ in current } },
            calendars: schedules.reduce(into: [:]) { $0.merge($1.calendars) { current, _ in current } },
            calendarDates: schedules.reduce(into: [:]) { partialResult, schedule in
                partialResult.merge(schedule.calendarDates) { current, _ in current }
            },
            stopTimesByStopId: schedules.reduce(into: [:]) { partialResult, schedule in
                partialResult.merge(schedule.stopTimesByStopId) { current, new in
                    (current + new).sorted { $0.departureSeconds < $1.departureSeconds }
                }
            },
            stopTimesByTripId: schedules.reduce(into: [:]) { partialResult, schedule in
                partialResult.merge(schedule.stopTimesByTripId) { current, new in
                    (current + new).sorted { lhs, rhs in
                        if lhs.sequence != rhs.sequence { return lhs.sequence < rhs.sequence }
                        return lhs.departureSeconds < rhs.departureSeconds
                    }
                }
            }
        )
    }
}
