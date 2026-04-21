import Foundation

enum Role: String, Codable, CaseIterable, Identifiable {
    case model
    case booker
    case manager
    case admin

    var id: String { rawValue }

    var title: String {
        switch self {
        case .model: return "Model"
        case .booker: return "Booker"
        case .manager: return "Manager"
        case .admin: return "Admin"
        }
    }

    var titleRu: String {
        switch self {
        case .model: return "Модель"
        case .booker: return "Букер"
        case .manager: return "Менеджер"
        case .admin: return "Админ"
        }
    }
}
