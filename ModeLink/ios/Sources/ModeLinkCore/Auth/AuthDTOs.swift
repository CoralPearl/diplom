import Foundation

struct OtpRequestBody: Codable {
    let email: String
    let purpose: String // "register"

    init(email: String, purpose: String = "register") {
        self.email = email
        self.purpose = purpose
    }
}

struct OtpRequestResponse: Codable {
    let ok: Bool
    let expiresAt: Date
}

struct OtpVerifyBody: Codable {
    let email: String
    let purpose: String
    let code: String
    let password: String
    let role: Role
    let adminRegistrationSecret: String?

    init(email: String, code: String, password: String, role: Role, adminRegistrationSecret: String? = nil, purpose: String = "register") {
        self.email = email
        self.purpose = purpose
        self.code = code
        self.password = password
        self.role = role
        self.adminRegistrationSecret = adminRegistrationSecret
    }
}

struct LoginBody: Codable {
    let email: String
    let password: String
}

struct AuthTokenResponse: Codable {
    let token: String
    let user: UserPublic
}

struct OkResponse: Codable {
    let ok: Bool
}
