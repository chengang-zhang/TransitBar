import Foundation

nonisolated struct TransitStop: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let detail: String?

    init(id: String, name: String, detail: String? = nil) {
        self.id = id
        self.name = name
        self.detail = detail
    }

    var favoriteName: String {
        guard let detail, !detail.isEmpty else { return name }
        return "\(name) - \(detail)"
    }
}
