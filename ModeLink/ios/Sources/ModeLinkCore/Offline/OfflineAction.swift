import Foundation

enum OfflineActionKind: String, Codable {
    case upsertModelProfile
    case createProject
}

enum OfflineActionStatus: String, Codable {
    case pending
    case failed
}

struct OfflineAction: Codable, Identifiable {
    var id: UUID
    var createdAt: Date
    var kind: OfflineActionKind
    var status: OfflineActionStatus
    var attemptCount: Int
    var lastError: String?
    var idempotencyKey: String?
    var payload: Payload

    enum Payload: Codable {
        case modelProfile(ModelProfileUpdate)
        case createProject(ProjectCreateRequest)

        private enum CodingKeys: String, CodingKey {
            case type
            case data
        }

        private enum PayloadType: String, Codable {
            case modelProfile
            case createProject
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let type = try container.decode(PayloadType.self, forKey: .type)
            switch type {
            case .modelProfile:
                let value = try container.decode(ModelProfileUpdate.self, forKey: .data)
                self = .modelProfile(value)
            case .createProject:
                let value = try container.decode(ProjectCreateRequest.self, forKey: .data)
                self = .createProject(value)
            }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case .modelProfile(let value):
                try container.encode(PayloadType.modelProfile, forKey: .type)
                try container.encode(value, forKey: .data)
            case .createProject(let value):
                try container.encode(PayloadType.createProject, forKey: .type)
                try container.encode(value, forKey: .data)
            }
        }
    }
}
