import Foundation

struct Project: Codable, Identifiable {
    let id: UUID
    let modelId: UUID
    var title: String
    var date: Date
    var location: String
    let createdAt: Date
}

struct ProjectCreateRequest: Codable {
    var modelId: UUID?
    var title: String
    var date: String
    var location: String
}

struct ProjectUpdateRequest: Codable {
    var title: String?
    var date: String?
    var location: String?
}
