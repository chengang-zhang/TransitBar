import Foundation

final class StaticGtfsTransitRepository: TransitRepository, @unchecked Sendable {
    private let schedule: GTFSSchedule
    private let routeTypesByStopId: [String: Set<Int>]
    private let calendar: Calendar
    private let horizon: TimeInterval
    private let legacyDefaultFeedId = "sound-transit"

    init(
        bundle: Bundle = .main,
        gtfsFeeds: [GTFSFeedResource] = GTFSFeedResource.defaultFeeds,
        calendar: Calendar = .current,
        horizon: TimeInterval = 6 * 60 * 60
    ) throws {
        let parser = GTFSParser(calendar: calendar)
        let schedules = try gtfsFeeds.map { feed in
            guard let url = bundle.url(forResource: feed.resourceName, withExtension: feed.resourceExtension) else {
                throw GTFSParserError.missingFile(feed.directoryName)
            }

            return try parser.parse(directoryURL: url, feedId: feed.id, feedName: feed.displayName)
        }

        self.schedule = GTFSSchedule.merging(schedules)
        self.routeTypesByStopId = StaticGtfsTransitRepository.routeTypesByStopId(for: self.schedule)
        self.calendar = calendar
        self.horizon = horizon
    }

    init(schedule: GTFSSchedule, calendar: Calendar = .current, horizon: TimeInterval = 6 * 60 * 60) {
        self.schedule = schedule
        self.routeTypesByStopId = StaticGtfsTransitRepository.routeTypesByStopId(for: schedule)
        self.calendar = calendar
        self.horizon = horizon
    }

    func searchLines(query: String, filter: StopSearchFilter) async throws -> [TransitLine] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)

        return schedule.routes.values
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
                lineSortKey(lhs).localizedStandardCompare(lineSortKey(rhs)) == .orderedAscending
            }
            .map { route in
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
        let tripIds = Set(trips(for: routeId).map(\.id))
        guard !tripIds.isEmpty else { return [] }

        let orderedStops = schedule.stopTimesByStopId
            .flatMap { _, stopTimes in
                stopTimes.filter { tripIds.contains($0.tripId) }
            }
            .reduce(into: [String: Int]()) { partialResult, stopTime in
                partialResult[stopTime.stopId] = min(partialResult[stopTime.stopId] ?? stopTime.sequence, stopTime.sequence)
            }
            .compactMap { stopId, sequence -> (GTFSStop, Int)? in
                guard let stop = schedule.stops[stopId],
                      schedule.stopTimesByStopId[stop.id] != nil,
                      stop.locationType != 1,
                      stop.locationType != 2
                else { return nil }

                return (stop, sequence)
            }
            .sorted { lhs, rhs in
                if lhs.1 != rhs.1 { return lhs.1 < rhs.1 }
                return lhs.0.searchDisplayName.localizedStandardCompare(rhs.0.searchDisplayName) == .orderedAscending
            }
            .map(\.0)

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

    func getDepartures(stopId: String) async throws -> [Departure] {
        upcomingDepartures(stopId: normalizedStopId(stopId), at: Date())
    }

    func upcomingDepartures(stopId: String, at now: Date) -> [Departure] {
        let stopTimes = schedule.stopTimesByStopId[stopId] ?? []
        let todayStart = calendar.startOfDay(for: now)
        let end = now.addingTimeInterval(horizon)

        return (-1...1).flatMap { dayOffset in
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
                routeName: route?.displayName ?? trip.routeId,
                destination: destination,
                departureTime: departureDate,
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
        let routeTypeRank = route.routeType == 3 ? "1" : "0"
        return "\(routeTypeRank)-\(route.displayName)"
    }

    private func includes(_ route: GTFSRoute, filter: StopSearchFilter) -> Bool {
        switch filter {
        case .all:
            return isRail(route) || isKingCountyBus(route)
        case .lightRail:
            return isRail(route)
        case .bus:
            return isKingCountyBus(route)
        }
    }

    private func isRail(_ route: GTFSRoute) -> Bool {
        [0, 1, 2].contains(route.routeType)
    }

    private func isKingCountyBus(_ route: GTFSRoute) -> Bool {
        route.routeType == 3 && route.feedId == "king-county"
    }

    private static func routeTypesByStopId(for schedule: GTFSSchedule) -> [String: Set<Int>] {
        schedule.stopTimesByStopId.reduce(into: [:]) { partialResult, entry in
            let routeTypes = Set(entry.value.compactMap { stopTime -> Int? in
                guard let trip = schedule.trips[stopTime.tripId] else { return nil }
                return schedule.routes[trip.routeId]?.routeType
            })

            partialResult[entry.key] = routeTypes
        }
    }
}

struct GTFSFeedResource: Sendable {
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
        GTFSFeedResource(id: "sound-transit", directoryName: "Sound Transit.bundle", displayName: "Sound Transit"),
        GTFSFeedResource(id: "king-county", directoryName: "King County.bundle", displayName: "King County")
    ]
}

private extension GTFSSchedule {
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
            }
        )
    }
}
