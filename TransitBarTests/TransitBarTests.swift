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
            stops: ["stop": GTFSStop(id: "stop", name: "Test Stop")],
            routes: ["route": GTFSRoute(id: "route", shortName: "2 Line", longName: "Link")],
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

}
