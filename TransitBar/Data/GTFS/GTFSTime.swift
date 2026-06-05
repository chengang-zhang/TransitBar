import Foundation

enum GTFSTime {
    static func seconds(from text: String) -> Int? {
        let parts = text.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }

        return parts[0] * 3600 + parts[1] * 60 + parts[2]
    }

    static func serviceDateKey(for date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d%02d%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }
}
