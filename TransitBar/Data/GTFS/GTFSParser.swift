import Foundation

enum GTFSParserError: Error {
    case missingFile(String)
    case invalidDate(String)
}

struct GTFSParser {
    private let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    func parse(directoryURL: URL) throws -> GTFSSchedule {
        let stops = try parseStops(read("stops.txt", in: directoryURL))
        let routes = try parseRoutes(read("routes.txt", in: directoryURL))
        let trips = try parseTrips(read("trips.txt", in: directoryURL))
        let stopTimes = try parseStopTimes(read("stop_times.txt", in: directoryURL))
        let calendars = try parseCalendars(read("calendar.txt", in: directoryURL))
        let calendarDates = try parseCalendarDates(read("calendar_dates.txt", in: directoryURL))

        return GTFSSchedule(
            stops: Dictionary(uniqueKeysWithValues: stops.map { ($0.id, $0) }),
            routes: Dictionary(uniqueKeysWithValues: routes.map { ($0.id, $0) }),
            trips: Dictionary(uniqueKeysWithValues: trips.map { ($0.id, $0) }),
            calendars: Dictionary(uniqueKeysWithValues: calendars.map { ($0.serviceId, $0) }),
            calendarDates: Dictionary(grouping: calendarDates, by: \.serviceId)
                .mapValues { dates in
                    Dictionary(uniqueKeysWithValues: dates.map { (GTFSTime.serviceDateKey(for: $0.date, calendar: calendar), $0) })
                },
            stopTimesByStopId: Dictionary(grouping: stopTimes, by: \.stopId)
                .mapValues { $0.sorted { $0.departureSeconds < $1.departureSeconds } }
        )
    }

    private func read(_ filename: String, in directoryURL: URL) throws -> String {
        let url = directoryURL.appendingPathComponent(filename)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw GTFSParserError.missingFile(filename)
        }
        return try String(contentsOf: url, encoding: .utf8)
    }

    private func parseStops(_ text: String) throws -> [GTFSStop] {
        CSVTable(text: text).rows.compactMap { row in
            guard let id = row["stop_id"], let name = row["stop_name"] else { return nil }
            return GTFSStop(id: id, name: name)
        }
    }

    private func parseRoutes(_ text: String) throws -> [GTFSRoute] {
        CSVTable(text: text).rows.compactMap { row in
            guard let id = row["route_id"] else { return nil }
            return GTFSRoute(
                id: id,
                shortName: row["route_short_name"] ?? "",
                longName: row["route_long_name"] ?? ""
            )
        }
    }

    private func parseTrips(_ text: String) throws -> [GTFSTrip] {
        CSVTable(text: text).rows.compactMap { row in
            guard
                let id = row["trip_id"],
                let routeId = row["route_id"],
                let serviceId = row["service_id"]
            else { return nil }

            return GTFSTrip(
                id: id,
                routeId: routeId,
                serviceId: serviceId,
                headsign: row["trip_headsign"] ?? ""
            )
        }
    }

    private func parseStopTimes(_ text: String) throws -> [GTFSStopTime] {
        CSVTable(text: text).rows.compactMap { row in
            guard
                let tripId = row["trip_id"],
                let stopId = row["stop_id"],
                let departure = row["departure_time"],
                let departureSeconds = GTFSTime.seconds(from: departure)
            else { return nil }

            return GTFSStopTime(
                tripId: tripId,
                stopId: stopId,
                departureSeconds: departureSeconds,
                sequence: Int(row["stop_sequence"] ?? "") ?? 0
            )
        }
    }

    private func parseCalendars(_ text: String) throws -> [GTFSCalendar] {
        try CSVTable(text: text).rows.compactMap { row in
            guard
                let serviceId = row["service_id"],
                let start = row["start_date"],
                let end = row["end_date"]
            else { return nil }

            return GTFSCalendar(
                serviceId: serviceId,
                activeWeekdays: activeWeekdays(from: row),
                startDate: try parseGTFSDate(start),
                endDate: try parseGTFSDate(end)
            )
        }
    }

    private func parseCalendarDates(_ text: String) throws -> [GTFSCalendarDate] {
        try CSVTable(text: text).rows.compactMap { row in
            guard
                let serviceId = row["service_id"],
                let date = row["date"],
                let exception = row["exception_type"],
                let exceptionType = Int(exception)
            else { return nil }

            return GTFSCalendarDate(
                serviceId: serviceId,
                date: try parseGTFSDate(date),
                exceptionType: exceptionType
            )
        }
    }

    private func activeWeekdays(from row: [String: String]) -> Set<Int> {
        let fields = [
            ("sunday", 1),
            ("monday", 2),
            ("tuesday", 3),
            ("wednesday", 4),
            ("thursday", 5),
            ("friday", 6),
            ("saturday", 7)
        ]

        return Set(fields.compactMap { field, weekday in
            row[field] == "1" ? weekday : nil
        })
    }

    private func parseGTFSDate(_ text: String) throws -> Date {
        guard text.count == 8 else { throw GTFSParserError.invalidDate(text) }

        let year = Int(text.prefix(4))
        let monthStart = text.index(text.startIndex, offsetBy: 4)
        let dayStart = text.index(text.startIndex, offsetBy: 6)
        let month = Int(text[monthStart..<dayStart])
        let day = Int(text[dayStart...])

        guard
            let year,
            let month,
            let day,
            let date = calendar.date(from: DateComponents(year: year, month: month, day: day))
        else {
            throw GTFSParserError.invalidDate(text)
        }

        return date
    }
}
