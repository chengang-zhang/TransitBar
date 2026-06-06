import Foundation

nonisolated struct TransitStop: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
}
