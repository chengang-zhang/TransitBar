import SwiftUI
import AppKit

struct RouteBadgeView: View {
    let routeName: String
    let routeColorHex: String?
    let routeTextColorHex: String?
    let routeType: Int?

    init(departure: Departure) {
        self.routeName = departure.routeName
        self.routeColorHex = departure.routeColorHex
        self.routeTextColorHex = departure.routeTextColorHex
        self.routeType = departure.routeType
    }

    init(line: TransitLine) {
        self.routeName = line.name
        self.routeColorHex = line.routeColorHex
        self.routeTextColorHex = line.routeTextColorHex
        self.routeType = line.routeType
    }

    var body: some View {
        Image(nsImage: RouteBadgeImageFactory.image(routeName: routeName, routeColorHex: routeColorHex, routeTextColorHex: routeTextColorHex, routeType: routeType))
            .resizable()
            .interpolation(.high)
            .frame(
                width: RouteBadgeImageFactory.size(routeName: routeName, routeType: routeType).width,
                height: RouteBadgeImageFactory.size(routeName: routeName, routeType: routeType).height
            )
            .accessibilityLabel(routeName)
    }
}

enum RouteBadgeImageFactory {
    static func size(for departure: Departure) -> CGSize {
        size(routeName: departure.routeName, routeType: departure.routeType)
    }

    static func image(for departure: Departure) -> NSImage {
        image(routeName: departure.routeName, routeColorHex: departure.routeColorHex, routeTextColorHex: departure.routeTextColorHex, routeType: departure.routeType)
    }

    static func size(routeName: String, routeType: Int?) -> CGSize {
        usesCircularBadge(routeName: routeName, routeType: routeType) ? CGSize(width: 24, height: 24) : CGSize(width: 48, height: 22)
    }

    static func image(routeName: String, routeColorHex: String?, routeTextColorHex: String?, routeType: Int?) -> NSImage {
        let size = size(routeName: routeName, routeType: routeType)
        let image = NSImage(size: size)

        image.lockFocus()
        defer { image.unlockFocus() }

        NSColor.clear.setFill()
        NSRect(origin: .zero, size: size).fill()

        let backgroundColor = nsColor(hex: routeColorHex) ?? fallbackRouteColor(routeType: routeType)
        let foregroundColor = nsColor(hex: routeTextColorHex) ?? .white
        let badgeRect = NSRect(origin: .zero, size: size).insetBy(dx: 1, dy: 1)

        backgroundColor.setFill()
        if usesCircularBadge(routeName: routeName, routeType: routeType) {
            NSBezierPath(ovalIn: badgeRect).fill()
        } else {
            NSBezierPath(roundedRect: badgeRect, xRadius: 4, yRadius: 4).fill()
        }

        let token = routeToken(routeName: routeName)
        let fontSize: CGFloat = usesCircularBadge(routeName: routeName, routeType: routeType) ? 12 : 10
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: fontSize, weight: .bold),
            .foregroundColor: foregroundColor
        ]
        let attributedToken = NSAttributedString(string: token, attributes: attributes)
        let tokenSize = attributedToken.size()
        let tokenOrigin = CGPoint(
            x: (size.width - tokenSize.width) / 2,
            y: (size.height - tokenSize.height) / 2
        )
        attributedToken.draw(at: tokenOrigin)

        return image
    }

    static func routeToken(for departure: Departure) -> String {
        routeToken(routeName: departure.routeName)
    }

    private static func routeToken(routeName: String) -> String {
        let trimmed = routeName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.localizedCaseInsensitiveContains("line") {
            return trimmed
                .replacingOccurrences(of: " Line", with: "", options: .caseInsensitive)
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return trimmed
    }

    private static func usesCircularBadge(routeName: String, routeType: Int?) -> Bool {
        routeToken(routeName: routeName).count <= 2 && routeType != 3
    }

    private static func fallbackRouteColor(routeType: Int?) -> NSColor {
        if routeType == 3 {
            return NSColor(calibratedRed: 0.0, green: 0.48, blue: 0.73, alpha: 1)
        }
        return .controlAccentColor
    }

    private static func nsColor(hex: String?) -> NSColor? {
        guard let hex else { return nil }

        let cleanHex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        guard cleanHex.count == 6, let value = Int(cleanHex, radix: 16) else { return nil }

        let red = CGFloat((value >> 16) & 0xff) / 255
        let green = CGFloat((value >> 8) & 0xff) / 255
        let blue = CGFloat(value & 0xff) / 255

        return NSColor(calibratedRed: red, green: green, blue: blue, alpha: 1)
    }
}
