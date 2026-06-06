//
//  TransitBarTests.swift
//  TransitBarTests
//
//  Created by Chengang Zhang on 6/5/26.
//

import Testing
import Foundation
@testable import TransitBar

struct TransitBarTests {

    @MainActor
    @Test func gtfsTimeSupportsHoursPastMidnight() {
        #expect(GTFSTime.seconds(from: "24:15:00") == 87_300)
        #expect(GTFSTime.seconds(from: "25:30:00") == 91_800)
        #expect(GTFSTime.seconds(from: "26:05:00") == 93_900)
    }

    @MainActor
    @Test func repositoryFindsLateNightDepartureFromPreviousServiceDay() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let serviceDate = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1))!
        let now = calendar.date(from: DateComponents(year: 2026, month: 1, day: 2, hour: 1, minute: 10))!
        let expectedDeparture = calendar.date(from: DateComponents(year: 2026, month: 1, day: 2, hour: 1, minute: 30))!

        let schedule = GTFSSchedule(
            stops: [
                "stop": GTFSStop(
                    id: "stop",
                    code: "100",
                    name: "Test Stop",
                    description: "Test Stop to Redmond",
                    locationType: nil,
                    parentStation: "station",
                    platformCode: "1",
                    feedName: "Test Feed"
                )
            ],
            routes: [
                "route": GTFSRoute(
                    id: "route",
                    feedId: "sound-transit",
                    feedName: "Sound Transit",
                    shortName: "2 Line",
                    longName: "Link",
                    routeDescription: "",
                    routeType: 0,
                    colorHex: "007CAD",
                    textColorHex: "FFFFFF"
                )
            ],
            trips: ["trip": GTFSTrip(id: "trip", routeId: "route", serviceId: "daily", headsign: "Redmond")],
            calendars: [
                "daily": GTFSCalendar(
                    serviceId: "daily",
                    activeWeekdays: Set(1...7),
                    startDate: serviceDate,
                    endDate: serviceDate
                )
            ],
            calendarDates: [:],
            stopTimesByStopId: [
                "stop": [
                    GTFSStopTime(
                        tripId: "trip",
                        stopId: "stop",
                        departureSeconds: GTFSTime.seconds(from: "25:30:00")!,
                        sequence: 1
                    )
                ]
            ]
        )

        let repository = StaticGtfsTransitRepository(schedule: schedule, calendar: calendar)
        let departures = repository.upcomingDepartures(stopId: "stop", at: now)

        #expect(departures.count == 1)
        #expect(departures.first?.routeName == "2 Line")
        #expect(departures.first?.destination == "Redmond")
        #expect(departures.first?.departureTime == expectedDeparture)
    }

    @MainActor
    @Test func repositoryFiltersLineSearchByRouteTypeAndReturnsStops() async throws {
        let schedule = GTFSSchedule(
            stops: [
                "rail-stop": GTFSStop(
                    id: "rail-stop",
                    code: "200",
                    name: "Test Station",
                    description: "",
                    locationType: 0,
                    parentStation: "",
                    platformCode: "",
                    feedName: "Test Feed"
                ),
                "bus-stop": GTFSStop(
                    id: "bus-stop",
                    code: "300",
                    name: "Test Station",
                    description: "",
                    locationType: 0,
                    parentStation: "",
                    platformCode: "",
                    feedName: "Test Feed"
                )
            ],
            routes: [
                "rail-route": GTFSRoute(
                    id: "rail-route",
                    feedId: "sound-transit",
                    feedName: "Sound Transit",
                    shortName: "2 Line",
                    longName: "Link",
                    routeDescription: "",
                    routeType: 0,
                    colorHex: "007CAD",
                    textColorHex: "FFFFFF"
                ),
                "bus-route": GTFSRoute(
                    id: "bus-route",
                    feedId: "king-county",
                    feedName: "King County",
                    shortName: "255",
                    longName: "Bus",
                    routeDescription: "Totem Lake TC-Kirkland TC-UW Link Sta-Univ Dist",
                    routeType: 3,
                    colorHex: "FDB71A",
                    textColorHex: "000000"
                ),
                "replacement-shuttle": GTFSRoute(
                    id: "replacement-shuttle",
                    feedId: "sound-transit",
                    feedName: "Sound Transit",
                    shortName: "Shuttle",
                    longName: "2 Line Shuttle Bus",
                    routeDescription: "",
                    routeType: 3,
                    colorHex: "FFB819",
                    textColorHex: "000000"
                )
            ],
            trips: [
                "rail-trip": GTFSTrip(id: "rail-trip", routeId: "rail-route", serviceId: "daily", headsign: "Redmond"),
                "bus-trip": GTFSTrip(id: "bus-trip", routeId: "bus-route", serviceId: "daily", headsign: "Kirkland")
            ],
            calendars: [:],
            calendarDates: [:],
            stopTimesByStopId: [
                "rail-stop": [GTFSStopTime(tripId: "rail-trip", stopId: "rail-stop", departureSeconds: 3600, sequence: 1)],
                "bus-stop": [GTFSStopTime(tripId: "bus-trip", stopId: "bus-stop", departureSeconds: 3600, sequence: 1)]
            ]
        )

        let repository = StaticGtfsTransitRepository(schedule: schedule)

        let railResults = try await repository.searchLines(query: "2", filter: .lightRail)
        let busResults = try await repository.searchLines(query: "255", filter: .bus)
        let allResults = try await repository.searchLines(query: "", filter: .all)
        let shuttleResults = try await repository.searchLines(query: "Shuttle", filter: .bus)
        let railStops = try await repository.getStops(lineId: "rail-route")

        #expect(railResults.map(\.id) == ["rail-route"])
        #expect(busResults.map(\.id) == ["bus-route"])
        #expect(allResults.map(\.id) == ["rail-route", "bus-route"])
        #expect(shuttleResults.isEmpty)
        #expect(railStops.map(\.id) == ["rail-stop"])
    }

}
