import Foundation

final class StaticGtfsTransitRepository: TransitRepository, @unchecked Sendable {
    private let schedule: GTFSSchedule
    private let calendar: Calendar
    private let horizon: TimeInterval

    init(
        bundle: Bundle = .main,
        gtfsDirectoryName: String = "GTFS",
        calendar: Calendar = .current,
        horizon: TimeInterval = 6 * 60 * 60
    ) throws {
        guard let url = bundle.url(forResource: gtfsDirectoryName, withExtension: nil) ?? bundle.resourceURL else {
            throw GTFSParserError.missingFile(gtfsDirectoryName)
        }

        self.schedule = try GTFSParser(calendar: calendar).parse(directoryURL: url)
        self.calendar = calendar
        self.horizon = horizon
    }

    init(schedule: GTFSSchedule, calendar: Calendar = .current, horizon: TimeInterval = 6 * 60 * 60) {
        self.schedule = schedule
        self.calendar = calendar
        self.horizon = horizon
    }

    func searchStops(query: String) async throws -> [TransitStop] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return [] }

        return schedule.stops.values
            .filter { $0.name.localizedCaseInsensitiveContains(trimmedQuery) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            .prefix(25)
            .map { TransitStop(id: $0.id, name: $0.name) }
    }

    func getDepartures(stopId: String) async throws -> [Departure] {
        upcomingDepartures(stopId: stopId, at: Date())
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
                departureTime: departureDate
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
}
