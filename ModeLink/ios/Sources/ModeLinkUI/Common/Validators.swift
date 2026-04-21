import Foundation

enum Validators {
    static func trimmed(_ s: String) -> String {
        s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Email

    static func isValidEmail(_ email: String) -> Bool {
        let t = trimmed(email)
        guard !t.isEmpty else { return false }
        // A pragmatic (not perfect) email check suitable for UI validation.
        let pattern = #"^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return t.range(of: pattern, options: .regularExpression) != nil
    }

    static func emailError(_ email: String) -> String? {
        let t = trimmed(email)
        if t.isEmpty { return "Email обязателен" }
        if !isValidEmail(t) { return "Некорректный email" }
        return nil
    }

    // MARK: - Password

    /// Strong-ish password rules for registration UX.
    /// - min 8 chars
    /// - at least 1 lowercase
    /// - at least 1 uppercase
    /// - at least 1 digit
    static func passwordStrengthError(_ password: String) -> String? {
        if password.isEmpty { return "Пароль обязателен" }
        if password.count < 8 { return "Минимум 8 символов" }

        let hasLower = password.range(of: #"[a-z]"#, options: .regularExpression) != nil
        let hasUpper = password.range(of: #"[A-Z]"#, options: .regularExpression) != nil
        let hasDigit = password.range(of: #"[0-9]"#, options: .regularExpression) != nil

        if !hasLower { return "Добавь строчную букву (a-z)" }
        if !hasUpper { return "Добавь заглавную букву (A-Z)" }
        if !hasDigit { return "Добавь цифру (0-9)" }

        return nil
    }

    // MARK: - Text

    static func requiredTextError(_ value: String, fieldName: String) -> String? {
        let t = trimmed(value)
        if t.isEmpty { return "\(fieldName) обязательно" }
        return nil
    }

    static func lengthError(_ value: String, fieldName: String, min: Int, max: Int) -> String? {
        let t = trimmed(value)
        if t.isEmpty { return "\(fieldName) обязательно" }
        if t.count < min { return "\(fieldName): минимум \(min) символа" }
        if t.count > max { return "\(fieldName): максимум \(max) символов" }
        return nil
    }

    // MARK: - Numbers

    static func intOptionalError(_ value: String, fieldName: String, range: ClosedRange<Int>) -> String? {
        let t = trimmed(value)
        guard !t.isEmpty else { return nil } // optional field
        guard let v = Int(t) else { return "\(fieldName): только цифры" }
        if !range.contains(v) {
            return "\(fieldName): \(range.lowerBound)–\(range.upperBound)"
        }
        return nil
    }

    static func doubleOptionalError(_ value: String, fieldName: String, range: ClosedRange<Double>) -> String? {
        let t = trimmed(value)
        guard !t.isEmpty else { return nil } // optional field
        let normalized = t.replacingOccurrences(of: ",", with: ".")
        guard let v = Double(normalized) else { return "\(fieldName): число" }
        if v < range.lowerBound || v > range.upperBound {
            return "\(fieldName): \(range.lowerBound)–\(range.upperBound)"
        }
        return nil
    }

    static func otpCodeError(_ code: String) -> String? {
        let t = trimmed(code)
        guard !t.isEmpty else { return "Код обязателен" }
        if t.count != 6 { return "Код должен быть из 6 цифр" }
        return nil
    }
}
