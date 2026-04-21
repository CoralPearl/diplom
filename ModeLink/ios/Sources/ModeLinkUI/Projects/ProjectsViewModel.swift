import Foundation
import Combine

enum ProjectsContext {
    /// Role=model (no modelId in requests)
    case currentModel
    /// Role=manager/admin (requests use modelId)
    case model(id: UUID)

    var modelId: UUID? {
        switch self {
        case .currentModel: return nil
        case .model(let id): return id
        }
    }

    var title: String {
        switch self {
        case .currentModel: return "Проекты"
        case .model: return "Проекты модели"
        }
    }
}

@MainActor
final class ProjectsViewModel: ObservableObject {
    @Published var projects: [Project] = []
    @Published var pending: [PendingProject] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    let context: ProjectsContext

    private var cancellables = Set<AnyCancellable>()

    init(context: ProjectsContext) {
        self.context = context

        // Keep pending list in sync with the offline queue.
        OfflineActionQueue.shared.$actions
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.rebuildPending()
            }
            .store(in: &cancellables)

        // When sync applies something, reload (server may now have created items).
        NotificationCenter.default.publisher(for: .modeLinkOfflineSyncDidApply)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { await self?.load() }
            }
            .store(in: &cancellables)
    }

    func load() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }

        do {
            if let modelId = context.modelId {
                let query = [URLQueryItem(name: "modelId", value: modelId.uuidString)]
                let list: [Project] = try await APIClient.shared.get("/projects", query: query)
                self.projects = list
            } else {
                let list: [Project] = try await APIClient.shared.get("/projects")
                self.projects = list
            }
            rebuildPending()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            rebuildPending()
        }
    }

    struct PendingProject: Identifiable {
        let id: UUID
        let title: String
        let location: String
        let date: Date
        let status: OfflineActionStatus
        let lastError: String?
    }

    private func rebuildPending() {
        let actions = OfflineActionQueue.shared.actions
            .filter { $0.kind == .createProject }
            .filter {
                switch $0.payload {
                case .createProject(let req):
                    if let modelId = context.modelId {
                        return req.modelId == modelId
                    }
                    return req.modelId == nil
                default:
                    return false
                }
            }

        let items: [PendingProject] = actions.compactMap { action in
            guard case .createProject(let req) = action.payload else { return nil }
            let date = ISO8601.date(from: req.date) ?? Date()
            return PendingProject(
                id: action.id,
                title: req.title,
                location: req.location,
                date: date,
                status: action.status,
                lastError: action.lastError
            )
        }

        self.pending = items
    }

    func create(title: String, date: Date, location: String) async -> Bool {
        errorMessage = nil

        let idempotencyKey = UUID().uuidString
        do {
            let body = ProjectCreateRequest(
                modelId: context.modelId,
                title: title,
                date: ISO8601.string(from: date),
                location: location
            )

            // If offline, queue immediately.
            if !NetworkMonitor.shared.isConnected {
                _ = OfflineActionQueue.shared.enqueueCreateProject(body, idempotencyKey: idempotencyKey)
                OfflineSyncEngine.shared.kick()
                rebuildPending()
                return true
            }

            // Online attempt with idempotency key.
            let created: Project = try await APIClient.shared.post("/projects", body: body, idempotencyKey: idempotencyKey)
            self.projects.insert(created, at: 0)
            return true
        } catch {
            if let apiErr = error as? APIError, (apiErr.isOfflineLike || apiErr.isTransient) {
                // Might have reached server; idempotency key makes retry safe.
                let body = ProjectCreateRequest(
                    modelId: context.modelId,
                    title: title,
                    date: ISO8601.string(from: date),
                    location: location
                )
                _ = OfflineActionQueue.shared.enqueueCreateProject(body, idempotencyKey: idempotencyKey)
                OfflineSyncEngine.shared.kick()
                rebuildPending()
                return true
            }

            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            return false
        }
    }

    func update(project: Project, title: String, date: Date, location: String) async -> Bool {
        errorMessage = nil
        do {
            let body = ProjectUpdateRequest(
                title: title,
                date: ISO8601.string(from: date),
                location: location
            )
            let updated: Project = try await APIClient.shared.put("/projects/\(project.id.uuidString)", body: body)
            if let idx = self.projects.firstIndex(where: { $0.id == project.id }) {
                self.projects[idx] = updated
            }
            return true
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            return false
        }
    }

    func delete(project: Project) async -> Bool {
        errorMessage = nil
        do {
            let _: OkResponse = try await APIClient.shared.delete("/projects/\(project.id.uuidString)")
            self.projects.removeAll { $0.id == project.id }
            return true
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            return false
        }
    }
}
