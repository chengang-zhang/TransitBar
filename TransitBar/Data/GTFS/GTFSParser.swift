import Foundation

nonisolated enum GTFSParserError: Error {
    case missingFile(String)
    case invalidDate(String)
}

nonisolated struct GTFSParser {
    private let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    func parse(directoryURL: URL, feedId: String, feedName: String) throws -> GTFSSchedule {
        let agencies = try parseAgencies(read("agency.txt", in: directoryURL))
        let stops = try parseStops(read("stops.txt", in: directoryURL), feedId: feedId, feedName: feedName)
        let routes = try parseRoutes(read("routes.txt", in: directoryURL), feedId: feedId, feedName: feedName, agencies: agencies)
        let trips = try parseTrips(read("trips.txt", in: directoryURL), feedId: feedId)
        let stopTimes = try parseStopTimes(read("stop_times.txt", in: directoryURL), feedId: feedId)
        let stopTimesByStopId = Dictionary(grouping: stopTimes, by: \.stopId)
            .mapValues { $0.sorted { $0.departureSeconds < $1.departureSeconds } }
        let stopTimesByTripId = Dictionary(grouping: stopTimes, by: \.tripId)
            .mapValues { $0.sorted { lhs, rhs in
                if lhs.sequence != rhs.sequence { return lhs.sequence < rhs.sequence }
                return lhs.departureSeconds < rhs.departureSeconds
            } }
        let calendars = try parseCalendars(read("calendar.txt", in: directoryURL), feedId: feedId)
        let calendarDates = try parseCalendarDates(read("calendar_dates.txt", in: directoryURL), feedId: feedId)

        return GTFSSchedule(
            stops: Dictionary(uniqueKeysWithValues: stops.map { ($0.id, $0) }),
            routes: Dictionary(uniqueKeysWithValues: routes.map { ($0.id, $0) }),
            trips: Dictionary(uniqueKeysWithValues: trips.map { ($0.id, $0) }),
            calendars: Dictionary(uniqueKeysWithValues: calendars.map { ($0.serviceId, $0) }),
            calendarDates: Dictionary(grouping: calendarDates, by: \.serviceId)
                .mapValues { dates in
                    Dictionary(uniqueKeysWithValues: dates.map { (GTFSTime.serviceDateKey(for: $0.date, calendar: calendar), $0) })
                },
            stopTimesByStopId: stopTimesByStopId,
            stopTimesByTripId: stopTimesByTripId
        )
    }

    private func read(_ filename: String, in directoryURL: URL) throws -> String {
        let url = directoryURL.appendingPathComponent(filename)
        if FileManager.default.fileExists(atPath: url.path) {
            return try String(contentsOf: url, encoding: .utf8)
        }

        let chunkPrefix = "\(filename).part"
        let chunkURLs = try FileManager.default
            .contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: nil)
            .filter { $0.lastPathComponent.hasPrefix(chunkPrefix) }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }

        guard !chunkURLs.isEmpty else {
            throw GTFSParserError.missingFile(filename)
        }

        return try chunkURLs.map { try String(contentsOf: $0, encoding: .utf8) }.joined()
    }

    private func parseAgencies(_ text: String) throws -> [String: String] {
        CSVTable(text: text).rows.reduce(into: [:]) { agencies, row in
            guard
                let id = row["agency_id"]?.trimmingCharacters(in: .whitespacesAndNewlines),
                let name = row["agency_name"],
                !id.isEmpty
            else { return }

            agencies[id] = agencies[id] ?? name
        }
    }

    private func parseStops(_ text: String, feedId: String, feedName: String) throws -> [GTFSStop] {
        CSVTable(text: text).rows.compactMap { row in
            guard let id = row["stop_id"], let name = row["stop_name"] else { return nil }
            return GTFSStop(
                id: namespaced(id, feedId: feedId),
                code: row["stop_code"] ?? "",
                name: name,
                description: row["stop_desc"] ?? "",
                locationType: Int(row["location_type"] ?? ""),
                parentStation: namespacedIfPresent(row["parent_station"] ?? "", feedId: feedId),
                platformCode: row["platform_code"] ?? "",
                feedName: feedName
            )
        }
    }

    private func parseRoutes(_ text: String, feedId: String, feedName: String, agencies: [String: String]) throws -> [GTFSRoute] {
        CSVTable(text: text).rows.compactMap { row in
            guard let id = row["route_id"] else { return nil }
            let routeAgencyName = row["agency_id"].flatMap { agencies[$0] } ?? feedName
            return GTFSRoute(
                id: namespaced(id, feedId: feedId),
                feedId: feedId,
                feedName: routeAgencyName,
                shortName: row["route_short_name"] ?? "",
                longName: row["route_long_name"] ?? "",
                routeDescription: row["route_desc"] ?? "",
                routeType: Int(row["route_type"] ?? ""),
                colorHex: row["route_color"] ?? "",
                textColorHex: row["route_text_color"] ?? ""
            )
        }
    }

    private func parseTrips(_ text: String, feedId: String) throws -> [GTFSTrip] {
        CSVTable(text: text).rows.compactMap { row in
            guard
                let id = row["trip_id"],
                let routeId = row["route_id"],
                let serviceId = row["service_id"]
            else { return nil }

            return GTFSTrip(
                id: namespaced(id, feedId: feedId),
                routeId: namespaced(routeId, feedId: feedId),
                serviceId: namespaced(serviceId, feedId: feedId),
                headsign: row["trip_headsign"] ?? ""
            )
        }
    }

    private func parseStopTimes(_ text: String, feedId: String) throws -> [GTFSStopTime] {
        let lines = text.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: true)
        guard let headerLine = lines.first else { return [] }

        let header = splitUnquotedCSVLine(headerLine)
        guard
            let tripIdIndex = header.firstIndex(of: "trip_id"),
            let stopIdIndex = header.firstIndex(of: "stop_id"),
            let departureIndex = header.firstIndex(of: "departure_time")
        else { return [] }

        let sequenceIndex = header.firstIndex(of: "stop_sequence")
        var stopTimes: [GTFSStopTime] = []
        stopTimes.reserveCapacity(100_000)

        guard lines.count > 1 else { return [] }
        lines[1].enumerateLines { line, _ in
            let fields = line.split(separator: ",", omittingEmptySubsequences: false)
            guard
                tripIdIndex < fields.count,
                stopIdIndex < fields.count,
                departureIndex < fields.count,
                let departureSeconds = GTFSTime.seconds(from: String(fields[departureIndex]))
            else { return }

            let sequence = sequenceIndex.flatMap { index -> Int? in
                guard index < fields.count else { return nil }
                return Int(fields[index])
            } ?? 0

            stopTimes.append(GTFSStopTime(
                tripId: namespaced(String(fields[tripIdIndex]), feedId: feedId),
                stopId: namespaced(String(fields[stopIdIndex]), feedId: feedId),
                departureSeconds: departureSeconds,
                sequence: sequence
            ))
        }

        return stopTimes
    }

    private func splitUnquotedCSVLine(_ line: Substring) -> [String] {
        line
            .split(separator: ",", omittingEmptySubsequences: false)
            .map { String($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
    }

    private func parseCalendars(_ text: String, feedId: String) throws -> [GTFSCalendar] {
        try CSVTable(text: text).rows.compactMap { row in
            guard
                let serviceId = row["service_id"],
                let start = row["start_date"],
                let end = row["end_date"]
            else { return nil }

            return GTFSCalendar(
                serviceId: namespaced(serviceId, feedId: feedId),
                activeWeekdays: activeWeekdays(from: row),
                startDate: try parseGTFSDate(start),
                endDate: try parseGTFSDate(end)
            )
        }
    }

    private func parseCalendarDates(_ text: String, feedId: String) throws -> [GTFSCalendarDate] {
        try CSVTable(text: text).rows.compactMap { row in
            guard
                let serviceId = row["service_id"],
                let date = row["date"],
                let exception = row["exception_type"],
                let exceptionType = Int(exception)
            else { return nil }

            return GTFSCalendarDate(
                serviceId: namespaced(serviceId, feedId: feedId),
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

    private func namespaced(_ value: String, feedId: String) -> String {
        "\(feedId):\(value)"
    }

    private func namespacedIfPresent(_ value: String, feedId: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "" : namespaced(value, feedId: feedId)
    }
}
