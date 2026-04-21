import Foundation

/// ISO8601 helper that supports fractional seconds.
enum ISO8601 {
    private static let formatterWithFractionalSeconds: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        f.timeZone = TimeZone(secondsFromGMT: 0)
        return f
    }()

    private static let formatterNoFractionalSeconds: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        f.timeZone = TimeZone(secondsFromGMT: 0)
        return f
    }()

    static func string(from date: Date) -> String {
        // Prefer fractional seconds for better round-trip with backend.
        return formatterWithFractionalSeconds.string(from: date)
    }

    static func date(from string: String) -> Date? {
        if let d = formatterWithFractionalSeconds.date(from: string) {
            return d
        }
        return formatterNoFractionalSeconds.date(from: string)
    }
}

extension JSONDecoder {
    static func modeLinkDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { d in
            let c = try d.singleValueContainer()
            let s = try c.decode(String.self)
            if let date = ISO8601.date(from: s) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: c, debugDescription: "Invalid ISO8601 date: \(s)")
        }
        return decoder
    }
}
