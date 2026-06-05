import Foundation

final class UserSettingsStore {
    private enum Key {
        static let favorites = "favorites"
        static let primaryStopId = "primaryStopId"
        static let refreshInterval = "refreshInterval"
        static let launchAtLogin = "launchAtLogin"
    }

    private let defaults: UserDefaults
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var favorites: [FavoriteStop] {
        get {
            guard let data = defaults.data(forKey: Key.favorites) else { return [] }
            return (try? decoder.decode([FavoriteStop].self, from: data)) ?? []
        }
        set {
            guard let data = try? encoder.encode(newValue) else { return }
            defaults.set(data, forKey: Key.favorites)
        }
    }

    var primaryStopId: String? {
        get { defaults.string(forKey: Key.primaryStopId) }
        set { defaults.set(newValue, forKey: Key.primaryStopId) }
    }

    var refreshInterval: TimeInterval {
        get {
            let value = defaults.double(forKey: Key.refreshInterval)
            return value > 0 ? value : 60
        }
        set { defaults.set(newValue, forKey: Key.refreshInterval) }
    }

    var launchAtLogin: Bool {
        get { defaults.bool(forKey: Key.launchAtLogin) }
        set { defaults.set(newValue, forKey: Key.launchAtLogin) }
    }
}
