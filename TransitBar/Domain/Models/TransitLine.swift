import Foundation

struct TransitLine: Identifiable, Equatable, Sendable {
    let id: String
    let sourceId: String
    let sourceName: String
    let name: String
    let details: String
    let routeColorHex: String?
    let routeTextColorHex: String?
    let routeType: Int?
}
