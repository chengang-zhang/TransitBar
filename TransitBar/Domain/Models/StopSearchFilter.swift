import Foundation

enum StopSearchFilter: String, CaseIterable, Identifiable, Sendable {
    case all
    case lightRail
    case bus

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            return "All"
        case .lightRail:
            return "Light Rail"
        case .bus:
            return "Bus"
        }
    }

    func includes(routeTypes: Set<Int>) -> Bool {
        switch self {
        case .all:
            return true
        case .lightRail:
            return !routeTypes.isDisjoint(with: [0, 1, 2])
        case .bus:
            return routeTypes.contains(3)
        }
    }
}
