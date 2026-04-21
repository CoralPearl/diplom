import Foundation

/// Persistent queue for "do it later" actions when offline.
///
/// Scope (current step):
/// - Update Model Profile (PUT /model-profile)
/// - Create Project (POST /projects) with Idempotency-Key
@MainActor
final class OfflineActionQueue: ObservableObject {
    static let shared = OfflineActionQueue()

    @Published private(set) var actions: [OfflineAction] = []

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private let ownerKey = "ModeLink.OfflineQueue.OwnerUserId"

    private init() {
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        decoder.dateDecodingStrategy = .iso8601
        encoder.dateEncodingStrategy = .iso8601
        loadFromDisk()
    }

    // MARK: - Owner isolation

    /// Call this on login / me bootstrap.
    func setOwner(userId: UUID) {
        let new = userId.uuidString
        let old = UserDefaults.standard.string(forKey: ownerKey)

        if let old, old != new {
            // Another user logged in → clear queue to prevent cross-account sync.
            actions = []
            saveToDisk()
        }
        UserDefaults.standard.set(new, forKey: ownerKey)
    }

    func clearOwner() {
        UserDefaults.standard.removeObject(forKey: ownerKey)
    }

    // MARK: - API

    func clearAll() {
        actions = []
        saveToDisk()
    }

    func remove(id: UUID) {
        actions.removeAll { $0.id == id }
        saveToDisk()
    }

    func markFailed(id: UUID, message: String) {
        guard let idx = actions.firstIndex(where: { $0.id == id }) else { return }
        actions[idx].status = .failed
        actions[idx].lastError = message
        actions[idx].attemptCount += 1
        saveToDisk()
    }

    func markPending(id: UUID) {
        guard let idx = actions.firstIndex(where: { $0.id == id }) else { return }
        actions[idx].status = .pending
        actions[idx].lastError = nil
        saveToDisk()
    }

    func bumpAttempt(id: UUID, lastError: String?) {
        guard let idx = actions.firstIndex(where: { $0.id == id }) else { return }
        actions[idx].attemptCount += 1
        actions[idx].lastError = lastError
        saveToDisk()
    }

    // MARK: - Enqueue helpers

    /// Keep only ONE pending profile update: overwrite payload with the latest values.
    @discardableResult
    func enqueueProfileUpdate(_ update: ModelProfileUpdate) -> UUID {
        if let idx = actions.firstIndex(where: {
            $0.kind == .upsertModelProfile
        }) {
            // overwrite
            actions[idx].createdAt = Date()
            actions[idx].status = .pending
            actions[idx].attemptCount = 0
            actions[idx].lastError = nil
            actions[idx].payload = .modelProfile(update)
            saveToDisk()
            return actions[idx].id
        }

        let action = OfflineAction(
            id: UUID(),
            createdAt: Date(),
            kind: .upsertModelProfile,
            status: .pending,
            attemptCount: 0,
            lastError: nil,
            idempotencyKey: nil,
            payload: .modelProfile(update)
        )

        actions.insert(action, at: 0)
        saveToDisk()
        return action.id
    }

    @discardableResult
    func enqueueCreateProject(_ req: ProjectCreateRequest, idempotencyKey: String) -> UUID {
        let action = OfflineAction(
            id: UUID(),
            createdAt: Date(),
            kind: .createProject,
            status: .pending,
            attemptCount: 0,
            lastError: nil,
            idempotencyKey: idempotencyKey,
            payload: .createProject(req)
        )

        actions.insert(action, at: 0)
        saveToDisk()
        return action.id
    }

    // MARK: - Queries

    func profileAction() -> OfflineAction? {
        actions.first(where: { $0.kind == .upsertModelProfile })
    }

    func pendingCreateProjects(for modelId: UUID?) -> [OfflineAction] {
        actions.filter { action in
            guard action.kind == .createProject else { return false }
            switch action.payload {
            case .createProject(let req):
                if let modelId {
                    return req.modelId == modelId
                }
                return req.modelId == nil
            default:
                return false
            }
        }
    }

    // MARK: - Persistence

    private func fileURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("ModeLink", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("offline_actions.json")
    }

    private func loadFromDisk() {
        let url = fileURL()
        guard let data = try? Data(contentsOf: url) else {
            actions = []
            return
        }
        do {
            actions = try decoder.decode([OfflineAction].self, from: data)
        } catch {
            actions = []
        }
    }

    private func saveToDisk() {
        let url = fileURL()
        do {
            let data = try encoder.encode(actions)
            try data.write(to: url, options: [.atomic])
        } catch {
            // non-fatal
        }
    }
}
