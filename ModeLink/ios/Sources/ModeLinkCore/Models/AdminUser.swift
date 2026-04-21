import Foundation

struct AdminUser: Codable, Identifiable {
    struct ModelProfileSummary: Codable, Identifiable {
        let id: UUID
        let fullName: String
    }

    let id: UUID
    let email: String
    let role: Role
    let isVerified: Bool
    let isBlocked: Bool
    let createdAt: Date
    let modelProfile: ModelProfileSummary?
}

struct AdminUpdateUserRequest: Codable {
    let role: Role?
    let isBlocked: Bool?

    init(role: Role? = nil, isBlocked: Bool? = nil) {
        self.role = role
        self.isBlocked = isBlocked
    }
}
