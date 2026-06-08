import Foundation

nonisolated protocol OneBusAwayResponseEnvelope {
    var code: Int { get }
    var text: String { get }
}

nonisolated struct OneBusAwayListResponse<Entry: Decodable>: Decodable, OneBusAwayResponseEnvelope {
    let code: Int
    let text: String
    let currentTime: Int64?
    let data: OneBusAwayListData<Entry>
}

nonisolated struct OneBusAwayEntryResponse<Entry: Decodable>: Decodable, OneBusAwayResponseEnvelope {
    let code: Int
    let text: String
    let currentTime: Int64?
    let data: OneBusAwayEntryData<Entry>
}

nonisolated struct OneBusAwayListData<Entry: Decodable>: Decodable {
    let list: [Entry]
    let references: OneBusAwayReferences?
}

nonisolated struct OneBusAwayEntryData<Entry: Decodable>: Decodable {
    let entry: Entry
    let references: OneBusAwayReferences?
}

nonisolated struct OneBusAwayReferences: Decodable {
    let agencies: [OneBusAwayAgency]?
    let routes: [OneBusAwayRoute]?
    let stops: [OneBusAwayStop]?
    let situations: [OneBusAwaySituation]?

    var agenciesById: [String: OneBusAwayAgency] {
        keyedById(agencies ?? [], id: \.id)
    }

    var routesById: [String: OneBusAwayRoute] {
        keyedById(routes ?? [], id: \.id)
    }

    var stopsById: [String: OneBusAwayStop] {
        keyedById(stops ?? [], id: \.id)
    }

    private func keyedById<Value>(_ values: [Value], id: KeyPath<Value, String>) -> [String: Value] {
        values.reduce(into: [:]) { result, value in
            let key = value[keyPath: id]
            if result[key] == nil {
                result[key] = value
            }
        }
    }
}

nonisolated struct OneBusAwayAgencyWithCoverage: Decodable {
    let agencyId: String
}

nonisolated struct OneBusAwayAgency: Decodable {
    let id: String
    let name: String
}

nonisolated struct OneBusAwayRoute: Decodable {
    let id: String
    let agencyId: String
    let shortName: String?
    let longName: String?
    let description: String?
    let color: String?
    let textColor: String?
    let type: Int?
    let url: String?

    var displayName: String {
        if let shortName, !shortName.isEmpty { return shortName }
        if let longName, !longName.isEmpty { return longName }
        return id
    }

    var detailsText: String {
        if let longName, !longName.isEmpty, longName != displayName { return longName }
        if let description, !description.isEmpty { return description }
        return ""
    }
}

nonisolated struct OneBusAwayStop: Decodable {
    let id: String
    let name: String
    let code: String?
    let direction: String?
}

nonisolated struct OneBusAwayStopsForRoute: Decodable {
    let stopIds: [String]
    let stopGroupings: [OneBusAwayStopGrouping]?

    var orderedStopIds: [String] {
        let groupedStopIds = stopGroupings?
            .filter { $0.ordered == true }
            .flatMap { $0.stopGroups ?? [] }
            .flatMap { $0.stopIds ?? [] } ?? []
        return deduplicated(groupedStopIds.isEmpty ? stopIds : groupedStopIds)
    }

    private func deduplicated(_ stopIds: [String]) -> [String] {
        var seenStopIds: Set<String> = []
        return stopIds.filter { stopId in
            seenStopIds.insert(stopId).inserted
        }
    }
}

nonisolated struct OneBusAwayStopGrouping: Decodable {
    let type: String?
    let ordered: Bool?
    let stopGroups: [OneBusAwayStopGroup]?
}

nonisolated struct OneBusAwayStopGroup: Decodable {
    let id: String?
    let name: OneBusAwayStopGroupName?
    let stopIds: [String]?
}

nonisolated struct OneBusAwayStopGroupName: Decodable {
    let name: String?
    let names: [String]?
    let type: String?
}

nonisolated struct OneBusAwayArrivalsAndDeparturesForStop: Decodable {
    let arrivalsAndDepartures: [OneBusAwayArrivalAndDeparture]
}

nonisolated struct OneBusAwayArrivalAndDeparture: Decodable {
    let routeId: String
    let routeShortName: String?
    let routeLongName: String?
    let tripHeadsign: String?
    let tripId: String?
    let stopId: String
    let predicted: Bool?
    let predictedArrivalTime: Int64?
    let predictedDepartureTime: Int64?
    let scheduledArrivalTime: Int64?
    let scheduledDepartureTime: Int64?
    let status: String?
    let situationIds: [String]?

    var bestDepartureTimeMilliseconds: Int64? {
        if predicted == true {
            return firstPositive(
                predictedDepartureTime,
                predictedArrivalTime,
                scheduledDepartureTime,
                scheduledArrivalTime
            )
        }

        return firstPositive(
            scheduledDepartureTime,
            scheduledArrivalTime,
            predictedDepartureTime,
            predictedArrivalTime
        )
    }

    var scheduledTimeMilliseconds: Int64? {
        firstPositive(scheduledDepartureTime, scheduledArrivalTime) ?? bestDepartureTimeMilliseconds
    }

    var routeDisplayName: String {
        if let routeShortName, !routeShortName.isEmpty { return routeShortName }
        if let routeLongName, !routeLongName.isEmpty { return routeLongName }
        return routeId
    }

    private func firstPositive(_ values: Int64?...) -> Int64? {
        values.compactMap { $0 }.first { $0 > 0 }
    }
}

nonisolated struct OneBusAwaySituation: Decodable {
    let id: String?
    let summary: OneBusAwayLocalizedText?
    let description: OneBusAwayLocalizedText?
}

nonisolated struct OneBusAwayLocalizedText: Decodable {
    let value: String?
}
