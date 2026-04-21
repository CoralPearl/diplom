import Foundation

struct ModelProfile: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    var fullName: String
    var height: Int?
    var weight: Int?
    var bust: Int?
    var waist: Int?
    var hips: Int?
    var shoeSize: Double?
    let createdAt: Date
    let updatedAt: Date
}

struct ModelProfileUpdate: Codable {
    var fullName: String?
    var height: Int?
    var weight: Int?
    var bust: Int?
    var waist: Int?
    var hips: Int?
    var shoeSize: Double?
}
