import Foundation

nonisolated enum OneBusAwayAPIKeyProvider {
    static let userDefaultsKey = "OBAAPIKey"
    static let environmentKey = "OBA_API_KEY"

    static func apiKey(
        userDefaults: UserDefaults = .standard,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> String? {
        if let value = userDefaults.string(forKey: userDefaultsKey), !value.isEmpty {
            return value
        }

        if let value = environment[environmentKey], !value.isEmpty {
            return value
        }

        return nil
    }
}

nonisolated enum OneBusAwayConfigurationError: LocalizedError {
    case missingAPIKey

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Missing OneBusAway API key."
        }
    }
}
