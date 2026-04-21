import Foundation
import Combine

extension Notification.Name {
    static let modeLinkOfflineSyncDidApply = Notification.Name("ModeLink.OfflineSyncDidApply")
}

/// Background-ish (in-app) worker that flushes `OfflineActionQueue` when:
/// - user is authenticated
/// - network is available
@MainActor
final class OfflineSyncEngine {
    static let shared = OfflineSyncEngine()

    private var cancellables = Set<AnyCancellable>()
    private var started = false
    private var syncTask: Task<Void, Never>?

    private init() {}

    func start() {
        guard !started else { return }
        started = true

        let net = NetworkMonitor.shared
        let app = AppState.shared

        Publishers.CombineLatest(net.$isConnected, app.$token)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isConnected, token in
                guard let self else { return }
                guard isConnected, token != nil else { return }
                self.kick()
            }
            .store(in: &cancellables)

        // Also run once at start (if conditions already met).
        kick()
    }

    func kick() {
        guard NetworkMonitor.shared.isConnected else { return }
        guard AppState.shared.token != nil else { return }
        guard syncTask == nil else { return }

        syncTask = Task { [weak self] in
            guard let self else { return }
            defer { Task { @MainActor in self.syncTask = nil } }
            await self.processQueue()
        }
    }

    private enum Outcome {
        case success
        case retryLater
        case failedPermanent(String)
    }

    private func processQueue() async {
        // Sequential sync: safer and easier.
        while NetworkMonitor.shared.isConnected, AppState.shared.token != nil {
            // Find first PENDING action.
            guard let action = OfflineActionQueue.shared.actions.first(where: { $0.status == .pending }) else {
                return
            }

            let outcome = await execute(action)
            switch outcome {
            case .success:
                OfflineActionQueue.shared.remove(id: action.id)
                NotificationCenter.default.post(name: .modeLinkOfflineSyncDidApply, object: nil, userInfo: ["kind": action.kind.rawValue])
                continue

            case .retryLater:
                // Stop loop: wait for better conditions.
                return

            case .failedPermanent(let message):
                OfflineActionQueue.shared.markFailed(id: action.id, message: message)
                NotificationCenter.default.post(name: .modeLinkOfflineSyncDidApply, object: nil, userInfo: ["kind": action.kind.rawValue])
                // Continue with next pending action.
                continue
            }
        }
    }

    private func execute(_ action: OfflineAction) async -> Outcome {
        do {
            switch action.payload {
            case .modelProfile(let update):
                _ = try await APIClient.shared.put("/model-profile", body: update)
                return .success

            case .createProject(let req):
                let key = action.idempotencyKey ?? action.id.uuidString
                _ = try await APIClient.shared.post("/projects", body: req, idempotencyKey: key)
                return .success
            }
        } catch let apiErr as APIError {
            // Retry later: offline/transient
            if apiErr.isOfflineLike || apiErr.isTransient {
                OfflineActionQueue.shared.bumpAttempt(id: action.id, lastError: apiErr.localizedDescription)
                return .retryLater
            }

            // Idempotency in progress on server (rare race) -> retry later
            if case .server(let status, let code, _) = apiErr, status == 409, code == "IdempotencyInProgress" {
                OfflineActionQueue.shared.bumpAttempt(id: action.id, lastError: apiErr.localizedDescription)
                return .retryLater
            }

            // Permanent failure.
            return .failedPermanent(apiErr.localizedDescription)
        } catch {
            return .failedPermanent(error.localizedDescription)
        }
    }
}
