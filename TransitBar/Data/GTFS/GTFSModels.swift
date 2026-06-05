import Foundation

struct GTFSStop: Sendable {
    let id: String
    let name: String
}

struct GTFSRoute: Sendable {
    let id: String
    let shortName: String
    let longName: String

    var displayName: String {
        if !shortName.isEmpty { return shortName }
        if !longName.isEmpty { return longName }
        return id
    }
}

struct GTFSTrip: Sendable {
    let id: String
    let routeId: String
    let serviceId: String
    let headsign: String
}

struct GTFSStopTime: Sendable {
    let tripId: String
    let stopId: String
    let departureSeconds: Int
    let sequence: Int
}

struct GTFSCalendar: Sendable {
    let serviceId: String
    let activeWeekdays: Set<Int>
    let startDate: Date
    let endDate: Date
}

struct GTFSCalendarDate: Sendable {
    let serviceId: String
    let date: Date
    let exceptionType: Int
}

struct GTFSSchedule: Sendable {
    let stops: [String: GTFSStop]
    let routes: [String: GTFSRoute]
    let trips: [String: GTFSTrip]
    let calendars: [String: GTFSCalendar]
    let calendarDates: [String: [String: GTFSCalendarDate]]
    let stopTimesByStopId: [String: [GTFSStopTime]]
}
