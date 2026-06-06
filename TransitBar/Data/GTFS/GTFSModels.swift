import Foundation

struct GTFSStop: Sendable {
    let id: String
    let code: String
    let name: String
    let description: String
    let locationType: Int?
    let parentStation: String
    let platformCode: String
    let feedName: String

    var searchDisplayName: String {
        var displayName = name

        let trimmedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedDescription.isEmpty,
           trimmedDescription.localizedCaseInsensitiveContains(name),
           !trimmedDescription.localizedCaseInsensitiveContains("Station -") {
            let detail = trimmedDescription
                .replacingOccurrences(of: name, with: "", options: [.caseInsensitive, .anchored])
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if !detail.isEmpty {
                displayName = "\(name) - \(detail)"
            }
        }

        let trimmedPlatform = platformCode.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedPlatform.isEmpty,
           !displayName.localizedCaseInsensitiveContains("bay \(trimmedPlatform)"),
           !displayName.localizedCaseInsensitiveContains("platform \(trimmedPlatform)") {
            displayName += " (Platform \(trimmedPlatform))"
        }

        return displayName
    }

    var disambiguatedSearchDisplayName: String {
        let trimmedCode = code.trimmingCharacters(in: .whitespacesAndNewlines)
        let suffix = trimmedCode.isEmpty ? feedName : "\(feedName) #\(trimmedCode)"
        return "\(searchDisplayName) - \(suffix)"
    }
}

struct GTFSRoute: Sendable {
    let id: String
    let feedId: String
    let feedName: String
    let shortName: String
    let longName: String
    let routeDescription: String
    let routeType: Int?
    let colorHex: String
    let textColorHex: String

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
