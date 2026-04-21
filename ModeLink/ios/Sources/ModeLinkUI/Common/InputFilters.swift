import Foundation

enum InputFilters {
    /// Keeps digits only. Optionally limits length.
    static func digits(_ input: String, maxLength: Int? = nil) -> String {
        let filtered = input.filter({ $0.isNumber })
        if let maxLength, filtered.count > maxLength {
            return String(filtered.prefix(maxLength))
        }
        return filtered
    }

    /// Keeps digits and at most one decimal separator. Normalizes separator to ".".
    ///
    /// Examples:
    /// - "37,5" -> "37.5"
    /// - "37..5" -> "37.5"
    /// - "ab12,34cd" -> "12.34"
    static func decimal(
        _ input: String,
        maxIntegerDigits: Int? = nil,
        maxFractionDigits: Int? = nil
    ) -> String {
        var result = ""

        var hasSeparator = false
        var inFraction = false
        var integerCount = 0
        var fractionCount = 0

        for ch in input {
            if ch.isNumber {
                if inFraction {
                    if let maxFractionDigits, fractionCount >= maxFractionDigits { continue }
                    fractionCount += 1
                } else {
                    if let maxIntegerDigits, integerCount >= maxIntegerDigits { continue }
                    integerCount += 1
                }
                result.append(ch)
                continue
            }

            if ch == "." || ch == "," {
                if hasSeparator { continue }
                hasSeparator = true
                inFraction = true
                result.append(".")
                continue
            }
        }

        return result
    }
}
