import Foundation

enum StopLabel: String, Codable, CaseIterable, Identifiable, Sendable {
    case home
    case work

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .home:
            "Home"
        case .work:
            "Work"
        }
    }
}
