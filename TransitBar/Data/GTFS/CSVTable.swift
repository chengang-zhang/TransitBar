import Foundation

struct CSVTable {
    let rows: [[String: String]]

    init(text: String) {
        let records = CSVTable.parseRecords(text)
        guard let header = records.first else {
            rows = []
            return
        }

        rows = records.dropFirst().map { record in
            Dictionary(uniqueKeysWithValues: header.enumerated().map { index, name in
                let value = index < record.count ? record[index] : ""
                return (name, value)
            })
        }
    }

    private static func parseRecords(_ text: String) -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var isQuoted = false
        var index = text.startIndex

        while index < text.endIndex {
            let character = text[index]
            let nextIndex = text.index(after: index)

            if character == "\"" {
                if isQuoted, nextIndex < text.endIndex, text[nextIndex] == "\"" {
                    field.append("\"")
                    index = text.index(after: nextIndex)
                    continue
                }
                isQuoted.toggle()
            } else if character == ",", !isQuoted {
                row.append(field)
                field = ""
            } else if character == "\n", !isQuoted {
                row.append(field.trimmingCharacters(in: .newlines))
                field = ""
                if !row.allSatisfy({ $0.isEmpty }) {
                    rows.append(row)
                }
                row = []
            } else if character != "\r" {
                field.append(character)
            }

            index = nextIndex
        }

        if !field.isEmpty || !row.isEmpty {
            row.append(field)
            if !row.allSatisfy({ $0.isEmpty }) {
                rows.append(row)
            }
        }

        return rows
    }
}
