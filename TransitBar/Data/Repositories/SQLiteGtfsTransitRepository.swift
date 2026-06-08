import Foundation
import SQLite3

actor SQLiteGtfsTransitRepository: TransitRepository {
    private let bundle: Bundle
    private let gtfsFeeds: [GTFSFeedResource]
    private let databaseURL: URL
    private let calendar: Calendar
    private let horizon: TimeInterval
    private let fallbackHorizon: TimeInterval
    private let legacyDefaultFeedId = "sound-transit"

    nonisolated(unsafe) private var database: OpaquePointer?
    private var calendarCache: CalendarCache?

    init(
        bundle: Bundle = .main,
        gtfsFeeds: [GTFSFeedResource] = GTFSFeedResource.defaultFeeds,
        databaseURL: URL? = nil,
        calendar: Calendar = .current,
        horizon: TimeInterval = 6 * 60 * 60,
        fallbackHorizon: TimeInterval = 36 * 60 * 60
    ) {
        self.bundle = bundle
        self.gtfsFeeds = gtfsFeeds
        self.databaseURL = databaseURL ?? Self.defaultDatabaseURL()
        self.calendar = calendar
        self.horizon = horizon
        self.fallbackHorizon = fallbackHorizon
    }

    deinit {
        if let database {
            sqlite3_close(database)
        }
    }

    func searchLines(query: String, filter: StopSearchFilter) async throws -> [TransitLine] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let routes = try allRoutes()
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

        return deduplicatedRoutes(routes).map { route in
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
        let routeId = try normalizedRouteId(lineId)
        let orderedStopIds = try representativeStopIds(for: routeId)
        let orderedStops = try orderedStopIds.compactMap { stopId -> GTFSStop? in
            guard let stop = try stop(id: stopId),
                  try hasStopTimes(stopId: stop.id),
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

    func getDepartures(stopId: String) async throws -> [Departure] {
        try upcomingDepartures(stopId: normalizedStopId(stopId), at: Date())
    }

    func warmCache() async throws {
        _ = try databaseConnection()
    }

    func upcomingDepartures(stopId: String, at now: Date) throws -> [Departure] {
        let stopTimes = try stopTimesForStop(stopId)
        let departures = try upcomingDepartures(from: stopTimes, at: now, horizon: horizon)

        if !departures.isEmpty {
            return departures
        }

        return Array(try upcomingDepartures(from: stopTimes, at: now, horizon: fallbackHorizon).prefix(1))
    }

    private func upcomingDepartures(from stopTimes: [GTFSStopTime], at now: Date, horizon: TimeInterval) throws -> [Departure] {
        let todayStart = calendar.startOfDay(for: now)
        let end = now.addingTimeInterval(horizon)
        let maxDayOffset = max(1, Int(ceil(horizon / (24 * 60 * 60))) + 1)

        return try (-1...maxDayOffset).flatMap { dayOffset in
            try departures(
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
    ) throws -> [Departure] {
        try stopTimes.compactMap { stopTime in
            guard
                let trip = try trip(id: stopTime.tripId),
                try isServiceActive(serviceId: trip.serviceId, on: serviceDate)
            else { return nil }

            let departureDate = serviceDate.addingTimeInterval(TimeInterval(stopTime.departureSeconds))
            guard departureDate >= now, departureDate <= end else { return nil }

            let route = try trip.routeId.isEmpty ? nil : route(id: trip.routeId)
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

    private func isServiceActive(serviceId: String, on serviceDate: Date) throws -> Bool {
        let cache = try loadedCalendarCache()
        let key = GTFSTime.serviceDateKey(for: serviceDate, calendar: calendar)
        if let exception = cache.calendarDates[serviceId]?[key] {
            return exception.exceptionType == 1
        }

        guard let service = cache.calendars[serviceId] else { return false }

        let day = calendar.startOfDay(for: serviceDate)
        guard day >= service.startDate, day <= service.endDate else { return false }

        let weekday = calendar.component(.weekday, from: day)
        return service.activeWeekdays.contains(weekday)
    }

    private func representativeStopIds(for routeId: String) throws -> [String] {
        let rows = try stopTimesForRoute(routeId)
        guard !rows.isEmpty else { return [] }

        var patterns: [String: SQLiteStopPattern] = [:]
        var currentTripId: String?
        var currentStopIds: [String] = []
        var seenStopIds = Set<String>()

        func storeCurrentPattern() {
            guard !currentStopIds.isEmpty else { return }
            let key = currentStopIds.joined(separator: "\u{1f}")
            if var pattern = patterns[key] {
                pattern.tripCount += 1
                patterns[key] = pattern
            } else {
                patterns[key] = SQLiteStopPattern(stopIds: currentStopIds, tripCount: 1)
            }
        }

        for stopTime in rows {
            if currentTripId != stopTime.tripId {
                storeCurrentPattern()
                currentTripId = stopTime.tripId
                currentStopIds = []
                seenStopIds = []
            }

            if seenStopIds.insert(stopTime.stopId).inserted {
                currentStopIds.append(stopTime.stopId)
            }
        }

        storeCurrentPattern()

        return patterns.values.sorted { lhs, rhs in
            if lhs.stopIds.count != rhs.stopIds.count { return lhs.stopIds.count > rhs.stopIds.count }
            if lhs.tripCount != rhs.tripCount { return lhs.tripCount > rhs.tripCount }
            return lhs.stopIds.joined(separator: "\u{1f}") < rhs.stopIds.joined(separator: "\u{1f}")
        }
        .first?
        .stopIds ?? []
    }

    private func normalizedStopId(_ stopId: String) throws -> String {
        if try stop(id: stopId) != nil {
            return stopId
        }

        let migratedStopId = "\(legacyDefaultFeedId):\(stopId)"
        return try stop(id: migratedStopId) == nil ? stopId : migratedStopId
    }

    private func normalizedRouteId(_ routeId: String) throws -> String {
        if try route(id: routeId) != nil {
            return routeId
        }

        let migratedRouteId = "\(legacyDefaultFeedId):\(routeId)"
        return try route(id: migratedRouteId) == nil ? routeId : migratedRouteId
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

private extension SQLiteGtfsTransitRepository {
    static func defaultDatabaseURL() -> URL {
        let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return baseURL
            .appendingPathComponent("TransitBar", isDirectory: true)
            .appendingPathComponent("gtfs-cache.sqlite")
    }

    func databaseConnection() throws -> OpaquePointer {
        if let database {
            return database
        }

        try FileManager.default.createDirectory(
            at: databaseURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        var openedDatabase: OpaquePointer?
        guard sqlite3_open_v2(databaseURL.path, &openedDatabase, SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK,
              let openedDatabase
        else {
            throw SQLiteGtfsError.openFailed(message: openedDatabase.map(Self.errorMessage) ?? "unknown")
        }

        database = openedDatabase
        try execute("PRAGMA journal_mode=WAL")
        try execute("PRAGMA synchronous=NORMAL")
        try rebuildIfNeeded()
        return openedDatabase
    }

    func rebuildIfNeeded() throws {
        try createSchemaIfNeeded()
        let fingerprint = try feedFingerprint()
        let cachedFingerprint = try metadataValue(forKey: "feed_fingerprint")

        guard cachedFingerprint != fingerprint else {
            return
        }

        let parser = GTFSParser(calendar: calendar)
        let schedules = try gtfsFeeds.map { feed in
            guard let url = bundle.url(forResource: feed.resourceName, withExtension: feed.resourceExtension) else {
                throw GTFSParserError.missingFile(feed.directoryName)
            }

            return try parser.parse(directoryURL: url, feedId: feed.id, feedName: feed.displayName)
        }
        let schedule = GTFSSchedule.merging(schedules)

        try execute("BEGIN IMMEDIATE TRANSACTION")
        do {
            try clearTables()
            try insert(schedule)
            try setMetadataValue(fingerprint, forKey: "feed_fingerprint")
            try setMetadataValue(Date().ISO8601Format(), forKey: "built_at")
            try execute("COMMIT")
            calendarCache = nil
        } catch {
            try? execute("ROLLBACK")
            throw error
        }
    }

    func createSchemaIfNeeded() throws {
        try execute("""
            CREATE TABLE IF NOT EXISTS metadata (
                key TEXT PRIMARY KEY NOT NULL,
                value TEXT NOT NULL
            )
        """)
        try execute("""
            CREATE TABLE IF NOT EXISTS stops (
                id TEXT PRIMARY KEY NOT NULL,
                code TEXT NOT NULL,
                name TEXT NOT NULL,
                description TEXT NOT NULL,
                location_type INTEGER,
                parent_station TEXT NOT NULL,
                platform_code TEXT NOT NULL,
                feed_name TEXT NOT NULL
            )
        """)
        try execute("""
            CREATE TABLE IF NOT EXISTS routes (
                id TEXT PRIMARY KEY NOT NULL,
                feed_id TEXT NOT NULL,
                feed_name TEXT NOT NULL,
                short_name TEXT NOT NULL,
                long_name TEXT NOT NULL,
                route_description TEXT NOT NULL,
                route_type INTEGER,
                color_hex TEXT NOT NULL,
                text_color_hex TEXT NOT NULL
            )
        """)
        try execute("""
            CREATE TABLE IF NOT EXISTS trips (
                id TEXT PRIMARY KEY NOT NULL,
                route_id TEXT NOT NULL,
                service_id TEXT NOT NULL,
                headsign TEXT NOT NULL
            )
        """)
        try execute("""
            CREATE TABLE IF NOT EXISTS calendars (
                service_id TEXT PRIMARY KEY NOT NULL,
                active_weekdays TEXT NOT NULL,
                start_date REAL NOT NULL,
                end_date REAL NOT NULL
            )
        """)
        try execute("""
            CREATE TABLE IF NOT EXISTS calendar_dates (
                service_id TEXT NOT NULL,
                date_key TEXT NOT NULL,
                exception_type INTEGER NOT NULL,
                PRIMARY KEY (service_id, date_key)
            )
        """)
        try execute("""
            CREATE TABLE IF NOT EXISTS stop_times (
                trip_id TEXT NOT NULL,
                stop_id TEXT NOT NULL,
                departure_seconds INTEGER NOT NULL,
                sequence INTEGER NOT NULL
            )
        """)
        try execute("CREATE INDEX IF NOT EXISTS idx_stop_times_stop_id ON stop_times(stop_id)")
        try execute("CREATE INDEX IF NOT EXISTS idx_stop_times_trip_id ON stop_times(trip_id)")
        try execute("CREATE INDEX IF NOT EXISTS idx_trips_route_id ON trips(route_id)")
    }

    func clearTables() throws {
        try execute("DELETE FROM metadata")
        try execute("DELETE FROM stops")
        try execute("DELETE FROM routes")
        try execute("DELETE FROM trips")
        try execute("DELETE FROM calendars")
        try execute("DELETE FROM calendar_dates")
        try execute("DELETE FROM stop_times")
    }

    func insert(_ schedule: GTFSSchedule) throws {
        try insertStops(Array(schedule.stops.values))
        try insertRoutes(Array(schedule.routes.values))
        try insertTrips(Array(schedule.trips.values))
        try insertCalendars(Array(schedule.calendars.values))
        try insertCalendarDates(schedule.calendarDates)
        try insertStopTimes(schedule.stopTimesByStopId.values.flatMap { $0 })
    }

    func feedFingerprint() throws -> String {
        try gtfsFeeds.map { feed in
            guard let url = bundle.url(forResource: feed.resourceName, withExtension: feed.resourceExtension) else {
                throw GTFSParserError.missingFile(feed.directoryName)
            }

            let files = try FileManager.default
                .contentsOfDirectory(at: url, includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey])
                .filter { !$0.hasDirectoryPath }
                .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }

            let fileFingerprints = try files.map { fileURL in
                let values = try fileURL.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
                let size = values.fileSize ?? 0
                let modified = values.contentModificationDate?.timeIntervalSince1970 ?? 0
                return "\(fileURL.lastPathComponent):\(size):\(modified)"
            }
            .joined(separator: "|")

            return "\(feed.id):\(fileFingerprints)"
        }
        .joined(separator: "||")
    }
}

private extension SQLiteGtfsTransitRepository {
    func allRoutes() throws -> [GTFSRoute] {
        try rows(sql: """
            SELECT id, feed_id, feed_name, short_name, long_name, route_description, route_type, color_hex, text_color_hex
            FROM routes
        """) { statement in
            GTFSRoute(
                id: text(statement, 0),
                feedId: text(statement, 1),
                feedName: text(statement, 2),
                shortName: text(statement, 3),
                longName: text(statement, 4),
                routeDescription: text(statement, 5),
                routeType: nullableInt(statement, 6),
                colorHex: text(statement, 7),
                textColorHex: text(statement, 8)
            )
        }
    }

    func route(id: String) throws -> GTFSRoute? {
        try firstRow(
            sql: """
                SELECT id, feed_id, feed_name, short_name, long_name, route_description, route_type, color_hex, text_color_hex
                FROM routes
                WHERE id = ?
            """,
            bindings: [.text(id)]
        ) { statement in
            GTFSRoute(
                id: text(statement, 0),
                feedId: text(statement, 1),
                feedName: text(statement, 2),
                shortName: text(statement, 3),
                longName: text(statement, 4),
                routeDescription: text(statement, 5),
                routeType: nullableInt(statement, 6),
                colorHex: text(statement, 7),
                textColorHex: text(statement, 8)
            )
        }
    }

    func stop(id: String) throws -> GTFSStop? {
        try firstRow(
            sql: """
                SELECT id, code, name, description, location_type, parent_station, platform_code, feed_name
                FROM stops
                WHERE id = ?
            """,
            bindings: [.text(id)]
        ) { statement in
            GTFSStop(
                id: text(statement, 0),
                code: text(statement, 1),
                name: text(statement, 2),
                description: text(statement, 3),
                locationType: nullableInt(statement, 4),
                parentStation: text(statement, 5),
                platformCode: text(statement, 6),
                feedName: text(statement, 7)
            )
        }
    }

    func trip(id: String) throws -> GTFSTrip? {
        try firstRow(
            sql: "SELECT id, route_id, service_id, headsign FROM trips WHERE id = ?",
            bindings: [.text(id)]
        ) { statement in
            GTFSTrip(
                id: text(statement, 0),
                routeId: text(statement, 1),
                serviceId: text(statement, 2),
                headsign: text(statement, 3)
            )
        }
    }

    func stopTimesForStop(_ stopId: String) throws -> [GTFSStopTime] {
        try rows(
            sql: """
                SELECT trip_id, stop_id, departure_seconds, sequence
                FROM stop_times
                WHERE stop_id = ?
                ORDER BY departure_seconds
            """,
            bindings: [.text(stopId)]
        ) { statement in
            GTFSStopTime(
                tripId: text(statement, 0),
                stopId: text(statement, 1),
                departureSeconds: int(statement, 2),
                sequence: int(statement, 3)
            )
        }
    }

    func stopTimesForRoute(_ routeId: String) throws -> [GTFSStopTime] {
        try rows(
            sql: """
                SELECT st.trip_id, st.stop_id, st.departure_seconds, st.sequence
                FROM stop_times st
                INNER JOIN trips t ON t.id = st.trip_id
                WHERE t.route_id = ?
                ORDER BY st.trip_id, st.sequence, st.departure_seconds
            """,
            bindings: [.text(routeId)]
        ) { statement in
            GTFSStopTime(
                tripId: text(statement, 0),
                stopId: text(statement, 1),
                departureSeconds: int(statement, 2),
                sequence: int(statement, 3)
            )
        }
    }

    func hasStopTimes(stopId: String) throws -> Bool {
        try firstRow(
            sql: "SELECT 1 FROM stop_times WHERE stop_id = ? LIMIT 1",
            bindings: [.text(stopId)]
        ) { _ in true } ?? false
    }

    func loadedCalendarCache() throws -> CalendarCache {
        if let calendarCache {
            return calendarCache
        }

        let calendars = try rows(sql: "SELECT service_id, active_weekdays, start_date, end_date FROM calendars") { statement in
            GTFSCalendar(
                serviceId: text(statement, 0),
                activeWeekdays: Set(text(statement, 1).split(separator: ",").compactMap { Int($0) }),
                startDate: Date(timeIntervalSinceReferenceDate: double(statement, 2)),
                endDate: Date(timeIntervalSinceReferenceDate: double(statement, 3))
            )
        }
        let calendarDates = try rows(sql: "SELECT service_id, date_key, exception_type FROM calendar_dates") { statement in
            CalendarDateRow(
                serviceId: text(statement, 0),
                dateKey: text(statement, 1),
                exceptionType: int(statement, 2)
            )
        }

        let cache = CalendarCache(
            calendars: Dictionary(uniqueKeysWithValues: calendars.map { ($0.serviceId, $0) }),
            calendarDates: Dictionary(grouping: calendarDates, by: \.serviceId)
                .mapValues { rows in
                    Dictionary(uniqueKeysWithValues: rows.map {
                        ($0.dateKey, GTFSCalendarDate(serviceId: $0.serviceId, date: Date(), exceptionType: $0.exceptionType))
                    })
                }
        )
        self.calendarCache = cache
        return cache
    }
}

private extension SQLiteGtfsTransitRepository {
    func insertStops(_ stops: [GTFSStop]) throws {
        try withStatement("""
            INSERT INTO stops (id, code, name, description, location_type, parent_station, platform_code, feed_name)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        """) { statement in
            for stop in stops {
                bind(.text(stop.id), to: statement, at: 1)
                bind(.text(stop.code), to: statement, at: 2)
                bind(.text(stop.name), to: statement, at: 3)
                bind(.text(stop.description), to: statement, at: 4)
                bind(stop.locationType.map(SQLiteValue.int) ?? .null, to: statement, at: 5)
                bind(.text(stop.parentStation), to: statement, at: 6)
                bind(.text(stop.platformCode), to: statement, at: 7)
                bind(.text(stop.feedName), to: statement, at: 8)
                try stepInsert(statement)
                sqlite3_reset(statement)
            }
        }
    }

    func insertRoutes(_ routes: [GTFSRoute]) throws {
        try withStatement("""
            INSERT INTO routes (id, feed_id, feed_name, short_name, long_name, route_description, route_type, color_hex, text_color_hex)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        """) { statement in
            for route in routes {
                bind(.text(route.id), to: statement, at: 1)
                bind(.text(route.feedId), to: statement, at: 2)
                bind(.text(route.feedName), to: statement, at: 3)
                bind(.text(route.shortName), to: statement, at: 4)
                bind(.text(route.longName), to: statement, at: 5)
                bind(.text(route.routeDescription), to: statement, at: 6)
                bind(route.routeType.map(SQLiteValue.int) ?? .null, to: statement, at: 7)
                bind(.text(route.colorHex), to: statement, at: 8)
                bind(.text(route.textColorHex), to: statement, at: 9)
                try stepInsert(statement)
                sqlite3_reset(statement)
            }
        }
    }

    func insertTrips(_ trips: [GTFSTrip]) throws {
        try withStatement("INSERT INTO trips (id, route_id, service_id, headsign) VALUES (?, ?, ?, ?)") { statement in
            for trip in trips {
                bind(.text(trip.id), to: statement, at: 1)
                bind(.text(trip.routeId), to: statement, at: 2)
                bind(.text(trip.serviceId), to: statement, at: 3)
                bind(.text(trip.headsign), to: statement, at: 4)
                try stepInsert(statement)
                sqlite3_reset(statement)
            }
        }
    }

    func insertCalendars(_ calendars: [GTFSCalendar]) throws {
        try withStatement("INSERT INTO calendars (service_id, active_weekdays, start_date, end_date) VALUES (?, ?, ?, ?)") { statement in
            for calendar in calendars {
                bind(.text(calendar.serviceId), to: statement, at: 1)
                bind(.text(calendar.activeWeekdays.sorted().map(String.init).joined(separator: ",")), to: statement, at: 2)
                bind(.double(calendar.startDate.timeIntervalSinceReferenceDate), to: statement, at: 3)
                bind(.double(calendar.endDate.timeIntervalSinceReferenceDate), to: statement, at: 4)
                try stepInsert(statement)
                sqlite3_reset(statement)
            }
        }
    }

    func insertCalendarDates(_ calendarDates: [String: [String: GTFSCalendarDate]]) throws {
        try withStatement("INSERT INTO calendar_dates (service_id, date_key, exception_type) VALUES (?, ?, ?)") { statement in
            for (serviceId, dates) in calendarDates {
                for (dateKey, date) in dates {
                    bind(.text(serviceId), to: statement, at: 1)
                    bind(.text(dateKey), to: statement, at: 2)
                    bind(.int(date.exceptionType), to: statement, at: 3)
                    try stepInsert(statement)
                    sqlite3_reset(statement)
                }
            }
        }
    }

    func insertStopTimes(_ stopTimes: [GTFSStopTime]) throws {
        try withStatement("INSERT INTO stop_times (trip_id, stop_id, departure_seconds, sequence) VALUES (?, ?, ?, ?)") { statement in
            for stopTime in stopTimes {
                bind(.text(stopTime.tripId), to: statement, at: 1)
                bind(.text(stopTime.stopId), to: statement, at: 2)
                bind(.int(stopTime.departureSeconds), to: statement, at: 3)
                bind(.int(stopTime.sequence), to: statement, at: 4)
                try stepInsert(statement)
                sqlite3_reset(statement)
            }
        }
    }

    func metadataValue(forKey key: String) throws -> String? {
        try firstRow(sql: "SELECT value FROM metadata WHERE key = ?", bindings: [.text(key)]) { statement in
            text(statement, 0)
        }
    }

    func setMetadataValue(_ value: String, forKey key: String) throws {
        try withStatement("INSERT OR REPLACE INTO metadata (key, value) VALUES (?, ?)") { statement in
            bind(.text(key), to: statement, at: 1)
            bind(.text(value), to: statement, at: 2)
            try stepInsert(statement)
        }
    }
}

private extension SQLiteGtfsTransitRepository {
    func rows<Value>(
        sql: String,
        bindings: [SQLiteValue] = [],
        map: (OpaquePointer) throws -> Value
    ) throws -> [Value] {
        _ = try databaseConnection()
        nonisolated(unsafe) var output: [Value] = []
        try withStatement(sql) { statement in
            bind(bindings, to: statement)
            while sqlite3_step(statement) == SQLITE_ROW {
                output.append(try map(statement))
            }
        }
        return output
    }

    func firstRow<Value>(
        sql: String,
        bindings: [SQLiteValue] = [],
        map: (OpaquePointer) throws -> Value
    ) throws -> Value? {
        _ = try databaseConnection()
        nonisolated(unsafe) var output: Value?
        try withStatement(sql) { statement in
            bind(bindings, to: statement)
            if sqlite3_step(statement) == SQLITE_ROW {
                output = try map(statement)
            }
        }
        return output
    }

    func execute(_ sql: String) throws {
        let database = try databaseConnectionWithoutRebuild()
        guard sqlite3_exec(database, sql, nil, nil, nil) == SQLITE_OK else {
            throw SQLiteGtfsError.executeFailed(sql: sql, message: Self.errorMessage(database))
        }
    }

    func withStatement(_ sql: String, _ body: (OpaquePointer) throws -> Void) throws {
        let database = try databaseConnectionWithoutRebuild()
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK,
              let statement
        else {
            throw SQLiteGtfsError.prepareFailed(sql: sql, message: Self.errorMessage(database))
        }

        defer { sqlite3_finalize(statement) }
        try body(statement)
    }

    func databaseConnectionWithoutRebuild() throws -> OpaquePointer {
        if let database {
            return database
        }

        var openedDatabase: OpaquePointer?
        guard sqlite3_open_v2(databaseURL.path, &openedDatabase, SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK,
              let openedDatabase
        else {
            throw SQLiteGtfsError.openFailed(message: openedDatabase.map(Self.errorMessage) ?? "unknown")
        }
        database = openedDatabase
        return openedDatabase
    }

    func bind(_ values: [SQLiteValue], to statement: OpaquePointer) {
        for (index, value) in values.enumerated() {
            bind(value, to: statement, at: Int32(index + 1))
        }
    }

    func bind(_ value: SQLiteValue, to statement: OpaquePointer, at index: Int32) {
        switch value {
        case .text(let value):
            sqlite3_bind_text(statement, index, value, -1, SQLITE_TRANSIENT)
        case .int(let value):
            sqlite3_bind_int(statement, index, Int32(value))
        case .double(let value):
            sqlite3_bind_double(statement, index, value)
        case .null:
            sqlite3_bind_null(statement, index)
        }
    }

    func stepInsert(_ statement: OpaquePointer) throws {
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw SQLiteGtfsError.executeFailed(sql: "insert", message: Self.errorMessage(try databaseConnectionWithoutRebuild()))
        }
    }

    func text(_ statement: OpaquePointer, _ index: Int32) -> String {
        guard let cString = sqlite3_column_text(statement, index) else { return "" }
        return String(cString: cString)
    }

    func int(_ statement: OpaquePointer, _ index: Int32) -> Int {
        Int(sqlite3_column_int(statement, index))
    }

    func nullableInt(_ statement: OpaquePointer, _ index: Int32) -> Int? {
        sqlite3_column_type(statement, index) == SQLITE_NULL ? nil : int(statement, index)
    }

    func double(_ statement: OpaquePointer, _ index: Int32) -> Double {
        sqlite3_column_double(statement, index)
    }

    static func errorMessage(_ database: OpaquePointer) -> String {
        sqlite3_errmsg(database).map { String(cString: $0) } ?? "unknown"
    }
}

nonisolated(unsafe) private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

private enum SQLiteValue {
    case text(String)
    case int(Int)
    case double(Double)
    case null
}

private enum SQLiteGtfsError: Error {
    case openFailed(message: String)
    case prepareFailed(sql: String, message: String)
    case executeFailed(sql: String, message: String)
}

private struct SQLiteStopPattern {
    let stopIds: [String]
    var tripCount: Int
}

private struct CalendarCache {
    let calendars: [String: GTFSCalendar]
    let calendarDates: [String: [String: GTFSCalendarDate]]
}

private struct CalendarDateRow {
    let serviceId: String
    let dateKey: String
    let exceptionType: Int
}
