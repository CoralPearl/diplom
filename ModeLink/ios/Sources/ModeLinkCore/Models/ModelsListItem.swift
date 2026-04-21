import Foundation

struct ModelsListItem: Codable, Identifiable {
    let id: UUID
    let userEmail: String
    let fullName: String
    let height: Int?
    let weight: Int?
    let bust: Int?
    let waist: Int?
    let hips: Int?
    let shoeSize: Double?
    let createdAt: Date
    let updatedAt: Date
    let portfolioCount: Int
    let projectsCount: Int
}

struct ModelDetails: Codable, Identifiable {
    let id: UUID
    let userEmail: String
    let fullName: String
    let height: Int?
    let weight: Int?
    let bust: Int?
    let waist: Int?
    let hips: Int?
    let shoeSize: Double?
    let createdAt: Date
    let updatedAt: Date
    let portfolioImages: [PortfolioImage]
    let projects: [Project]
}
