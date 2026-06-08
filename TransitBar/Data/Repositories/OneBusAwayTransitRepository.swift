import Foundation

nonisolated final class OneBusAwayTransitRepository: TransitRepository, @unchecked Sendable {
    private let client: OneBusAwayClient
    private let calendar: Calendar
    private let agencies = Cache<[String: OneBusAwayAgency]>()
    private let routes = Cache<[OneBusAwayRoute]>()

    init(client: OneBusAwayClient, calendar: Calendar = .current) {
        self.client = client
        self.calendar = calendar
    }

    func searchLines(query: String, filter: StopSearchFilter) async throws -> [TransitLine] {
        let agenciesById = try await loadAgencies()
        let allRoutes = try await loadRoutes(agencyIds: Array(agenciesById.keys).sorted())
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)

        return allRoutes
            .filter { route in
                filter.includes(routeType: route.type)
                    && (
                        trimmedQuery.isEmpty
                            || route.displayName.localizedCaseInsensitiveContains(trimmedQuery)
                            || route.detailsText.localizedCaseInsensitiveContains(trimmedQuery)
                            || (agenciesById[route.agencyId]?.name.localizedCaseInsensitiveContains(trimmedQuery) ?? false)
                    )
            }
            .sorted { lhs, rhs in
                let lhsKey = "\(routeTypeRank(lhs.type))-\(agenciesById[lhs.agencyId]?.name ?? lhs.agencyId)-\(lhs.displayName)"
                let rhsKey = "\(routeTypeRank(rhs.type))-\(agenciesById[rhs.agencyId]?.name ?? rhs.agencyId)-\(rhs.displayName)"
                return lhsKey.localizedStandardCompare(rhsKey) == .orderedAscending
            }
            .map { route in
                TransitLine(
                    id: route.id,
                    sourceId: route.agencyId,
                    sourceName: agenciesById[route.agencyId]?.name ?? route.agencyId,
                    name: route.displayName,
                    details: route.detailsText,
                    routeColorHex: route.color,
                    routeTextColorHex: route.textColor,
                    routeType: route.type
                )
            }
    }

    func getStops(lineId: String) async throws -> [TransitStop] {
        let response = try await client.stops(forRoute: lineId)
        let stopsById = response.data.references?.stopsById ?? [:]

        return response.data.entry.orderedStopIds.compactMap { stopId in
            guard let stop = stopsById[stopId] else { return nil }
            return TransitStop(id: stop.id, name: stop.name, detail: stopDetail(stop))
        }
    }

    func getDepartures(stopId: String) async throws -> [Departure] {
        let response = try await client.arrivalsAndDepartures(forStop: stopId)
        let routesById = response.data.references?.routesById ?? [:]
        let now = Date()

        return response.data.entry.arrivalsAndDepartures
            .compactMap { arrival -> Departure? in
                guard let departureMilliseconds = arrival.bestDepartureTimeMilliseconds else {
                    return nil
                }

                let departureTime = date(milliseconds: departureMilliseconds)
                guard departureTime >= now.addingTimeInterval(-60) else { return nil }

                let route = routesById[arrival.routeId]
                let scheduledTime = arrival.scheduledTimeMilliseconds.map(date(milliseconds:)) ?? departureTime
                let destination = arrival.tripHeadsign?.isEmpty == false
                    ? arrival.tripHeadsign ?? ""
                    : route?.detailsText ?? ""

                return Departure(
                    id: "\(arrival.tripId ?? arrival.routeId)-\(arrival.stopId)-\(departureMilliseconds)",
                    tripId: arrival.tripId,
                    stopId: arrival.stopId,
                    routeId: arrival.routeId,
                    routeName: route?.displayName ?? arrival.routeDisplayName,
                    destination: destination,
                    departureTime: departureTime,
                    scheduledTime: scheduledTime,
                    routeColorHex: route?.color,
                    routeTextColorHex: route?.textColor,
                    routeType: route?.type,
                    predictionSource: arrival.predicted == true ? .realtime : .scheduled
                )
            }
            .sorted { $0.departureTime < $1.departureTime }
            .prefix(12)
            .map { $0 }
    }

    private func loadAgencies() async throws -> [String: OneBusAwayAgency] {
        if let cached = await agencies.value {
            return cached
        }

        let response = try await client.agenciesWithCoverage()
        let references = response.data.references?.agenciesById ?? [:]
        let agencyIds = response.data.list.map(\.agencyId)
        let agenciesById = references.filter { agencyIds.contains($0.key) }
        await agencies.set(agenciesById)
        return agenciesById
    }

    private func loadRoutes(agencyIds: [String]) async throws -> [OneBusAwayRoute] {
        if let cached = await routes.value {
            return cached
        }

        let loadedRoutes = try await withThrowingTaskGroup(of: Result<[OneBusAwayRoute], Error>.self) { group in
            for agencyId in agencyIds {
                group.addTask { [client] in
                    do {
                        return .success(try await client.routes(forAgency: agencyId).data.list)
                    } catch {
                        return .failure(error)
                    }
                }
            }

            var routes: [OneBusAwayRoute] = []
            var lastError: Error?
            for try await result in group {
                switch result {
                case .success(let agencyRoutes):
                    routes.append(contentsOf: agencyRoutes)
                case .failure(let error):
                    lastError = error
                }
            }

            if routes.isEmpty, let lastError {
                throw lastError
            }
            return routes
        }

        await routes.set(loadedRoutes)
        return loadedRoutes
    }

    private func stopDetail(_ stop: OneBusAwayStop) -> String? {
        if let direction = stop.direction, !direction.isEmpty {
            return directionLabel(direction)
        }

        if let platform = platformLabel(stop.id) {
            return platform
        }

        if let code = stop.code, !code.isEmpty {
            return "Stop \(code)"
        }

        return nil
    }

    private func platformLabel(_ stopId: String) -> String? {
        guard let platformPrefixRange = stopId.range(of: "-T", options: .backwards) else {
            return nil
        }

        let platformNumber = stopId[platformPrefixRange.upperBound...]
        guard !platformNumber.isEmpty, platformNumber.allSatisfy(\.isNumber) else {
            return nil
        }

        return "Platform \(platformNumber)"
    }

    private func directionLabel(_ direction: String) -> String {
        switch direction.uppercased() {
        case "N": return "Northbound"
        case "S": return "Southbound"
        case "E": return "Eastbound"
        case "W": return "Westbound"
        case "NE": return "Northeastbound"
        case "NW": return "Northwestbound"
        case "SE": return "Southeastbound"
        case "SW": return "Southwestbound"
        default: return "Direction \(direction)"
        }
    }

    private func date(milliseconds: Int64) -> Date {
        Date(timeIntervalSince1970: TimeInterval(milliseconds) / 1_000)
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

    private actor Cache<Value> {
        var value: Value?

        func set(_ value: Value) {
            self.value = value
        }
    }
}
