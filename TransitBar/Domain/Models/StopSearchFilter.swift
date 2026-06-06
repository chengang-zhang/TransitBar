import Foundation

nonisolated enum StopSearchFilter: String, CaseIterable, Identifiable, Sendable {
    case all
    case rail
    case bus
    case ferry

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            return "All"
        case .rail:
            return "Rail"
        case .bus:
            return "Bus"
        case .ferry:
            return "Ferry"
        }
    }

    func includes(routeType: Int?) -> Bool {
        guard let routeType else { return self == .all }

        switch self {
        case .all:
            return true
        case .rail:
            return [0, 1, 2].contains(routeType)
        case .bus:
            return routeType == 3
        case .ferry:
            return routeType == 4
        }
    }

    func includes(routeTypes: Set<Int>) -> Bool {
        switch self {
        case .all:
            return true
        case .rail:
            return !routeTypes.isDisjoint(with: [0, 1, 2])
        case .bus:
            return routeTypes.contains(3)
        case .ferry:
            return routeTypes.contains(4)
        }
    }
}
