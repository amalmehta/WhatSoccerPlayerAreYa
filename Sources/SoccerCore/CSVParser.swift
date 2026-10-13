import Foundation

/// A small RFC 4180 CSV reader: quoted fields, escaped quotes, commas and newlines inside quotes, CRLF, BOM.
public enum CSVParser {
    public static func parse(_ text: String) -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var inQuotes = false
        var iterator = text.unicodeScalars.makeIterator()
        var pending: Unicode.Scalar? = nil

        func next() -> Unicode.Scalar? {
            if let p = pending { pending = nil; return p }
            return iterator.next()
        }
        func endRow() {
            row.append(field)
            field = ""
            if !(row.count == 1 && row[0].isEmpty) { rows.append(row) }
            row = []
        }

        while let c = next() {
            if inQuotes {
                if c == "\"" {
                    if let n = next() {
                        if n == "\"" { field.unicodeScalars.append("\"") } else { inQuotes = false; pending = n }
                    } else { inQuotes = false }
                } else {
                    field.unicodeScalars.append(c)
                }
                continue
            }
            switch c {
            case "\u{FEFF}" where rows.isEmpty && row.isEmpty && field.isEmpty:
                continue
            case "\"" where field.isEmpty:
                inQuotes = true
            case ",":
                row.append(field); field = ""
            case "\r":
                if let n = next(), n != "\n" { pending = n }
                endRow()
            case "\n":
                endRow()
            default:
                field.unicodeScalars.append(c)
            }
        }
        if !field.isEmpty || !row.isEmpty { endRow() }
        return rows
    }
}
