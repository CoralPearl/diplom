import Foundation

struct UserPublic: Codable, Identifiable {
    let id: UUID
    let email: String
    let role: Role
    let isVerified: Bool
}

/// Response of GET /auth/me
struct MeResponse: Codable, Identifiable {
    let id: UUID
    let email: String
    let role: Role
    let isVerified: Bool
    let modelProfile: ModelProfile?
}
