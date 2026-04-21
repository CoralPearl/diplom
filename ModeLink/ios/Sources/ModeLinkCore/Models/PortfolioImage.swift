import Foundation

struct PortfolioImage: Codable, Identifiable {
    let id: UUID
    let modelId: UUID
    let imageUrl: URL
    let storageKey: String?
    let createdAt: Date
}
