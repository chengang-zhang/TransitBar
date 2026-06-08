import Foundation

nonisolated final class OneBusAwayClient: @unchecked Sendable {
    private let baseURL: URL
    private let apiKey: String
    private let urlSession: URLSession

    init(
        apiKey: String,
        baseURL: URL = URL(string: "https://api.pugetsound.onebusaway.org/api/where")!,
        urlSession: URLSession = .shared
    ) {
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.urlSession = urlSession
    }

    func agenciesWithCoverage() async throws -> OneBusAwayListResponse<OneBusAwayAgencyWithCoverage> {
        try await get("agencies-with-coverage")
    }

    func routes(forAgency agencyId: String) async throws -> OneBusAwayListResponse<OneBusAwayRoute> {
        try await get("routes-for-agency/\(agencyId)")
    }

    func stops(forRoute routeId: String) async throws -> OneBusAwayEntryResponse<OneBusAwayStopsForRoute> {
        try await get("stops-for-route/\(routeId)")
    }

    func arrivalsAndDepartures(
        forStop stopId: String,
        minutesBefore: Int = 0,
        minutesAfter: Int = 360
    ) async throws -> OneBusAwayEntryResponse<OneBusAwayArrivalsAndDeparturesForStop> {
        try await get(
            "arrivals-and-departures-for-stop/\(stopId)",
            queryItems: [
                URLQueryItem(name: "minutesBefore", value: "\(minutesBefore)"),
                URLQueryItem(name: "minutesAfter", value: "\(minutesAfter)")
            ]
        )
    }

    private func get<Response: Decodable>(
        _ path: String,
        queryItems: [URLQueryItem] = []
    ) async throws -> Response {
        let url = try url(path: path, queryItems: queryItems)
        var request = URLRequest(url: url)
        request.timeoutInterval = 12

        let (data, response) = try await urlSession.data(for: request)
        if let httpResponse = response as? HTTPURLResponse,
           !(200..<300).contains(httpResponse.statusCode) {
            throw OneBusAwayClientError.httpStatus(httpResponse.statusCode)
        }

        let decoded = try JSONDecoder().decode(Response.self, from: data)
        if let response = decoded as? any OneBusAwayResponseEnvelope, response.code != 200 {
            throw OneBusAwayClientError.api(code: response.code, text: response.text)
        }
        return decoded
    }

    private func url(path: String, queryItems: [URLQueryItem]) throws -> URL {
        let endpoint = baseURL
            .appending(path: path)
            .appendingPathExtension("json")
        guard var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false) else {
            throw OneBusAwayClientError.invalidURL
        }

        components.queryItems = queryItems + [URLQueryItem(name: "key", value: apiKey)]

        guard let url = components.url else {
            throw OneBusAwayClientError.invalidURL
        }
        return url
    }
}

nonisolated enum OneBusAwayClientError: LocalizedError {
    case invalidURL
    case httpStatus(Int)
    case api(code: Int, text: String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Unable to build OneBusAway request URL."
        case .httpStatus(let statusCode):
            return "OneBusAway request failed with HTTP \(statusCode)."
        case .api(let code, let text):
            return "OneBusAway request failed with code \(code): \(text)"
        }
    }
}
