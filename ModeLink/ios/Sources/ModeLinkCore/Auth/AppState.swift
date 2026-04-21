import Foundation
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()

    @Published private(set) var isBootstrapping: Bool = true
    @Published private(set) var token: String? = nil
    @Published private(set) var me: MeResponse? = nil

    var isAuthenticated: Bool { token != nil }

    private let lastUserKey = "ModeLink.LastUser"

    private init() {
        let stored = KeychainStore.shared.loadToken()
        self.token = stored

        APIClient.shared.tokenProvider = { [weak self] in
            return self?.token
        }

        // Best-effort: restore last known user for offline-friendly routing.
        if stored != nil, let user = loadLastUser() {
            self.me = MeResponse(id: user.id, email: user.email, role: user.role, isVerified: user.isVerified, modelProfile: nil)

            // Set offline-queue owner to prevent cross-account sync.
            OfflineActionQueue.shared.setOwner(userId: user.id)
        }
    }

    func bootstrap() {
        Task {
            defer { self.isBootstrapping = false }

            guard token != nil else {
                self.me = nil
                return
            }

            do {
                let meResp: MeResponse = try await APIClient.shared.get("/auth/me", requiresAuth: true)
                self.me = meResp

                OfflineActionQueue.shared.setOwner(userId: meResp.id)
                OfflineSyncEngine.shared.kick()

                // Persist for offline routing.
                let user = UserPublic(id: meResp.id, email: meResp.email, role: meResp.role, isVerified: meResp.isVerified)
                saveLastUser(user)
            } catch let apiErr as APIError {
                // If token is invalid/expired → logout.
                if apiErr.isAuthError {
                    await logout()
                    return
                }

                // Otherwise: keep session (offline / temporary issues).
                // `me` might already contain a restored minimal user.
                // If it is still nil, the UI will show a friendly offline gate.
            } catch {
                // Unknown error: keep session; do not force logout.
            }
        }
    }

    func setSession(token: String, user: UserPublic) {
        self.token = token
        do {
            try KeychainStore.shared.saveToken(token)
        } catch {
            // Non-fatal: session still works until app restart
            print("Keychain save error: \(error)")
        }

        // Persist user for offline-friendly routing.
        saveLastUser(user)

        OfflineActionQueue.shared.setOwner(userId: user.id)
        OfflineSyncEngine.shared.kick()

        // Immediately set minimal me
        self.me = MeResponse(id: user.id, email: user.email, role: user.role, isVerified: user.isVerified, modelProfile: nil)

        Task {
            // Refresh /auth/me (contains modelProfile)
            do {
                let meResp: MeResponse = try await APIClient.shared.get("/auth/me", requiresAuth: true)
                self.me = meResp

                let u = UserPublic(id: meResp.id, email: meResp.email, role: meResp.role, isVerified: meResp.isVerified)
                saveLastUser(u)
            } catch {
                // ignore
            }
        }
    }

    func logout() async {
        self.me = nil
        self.token = nil

        do {
            try KeychainStore.shared.deleteToken()
        } catch {
            print("Keychain delete error: \(error)")
        }

        UserDefaults.standard.removeObject(forKey: lastUserKey)

        // Clear response cache so next user doesn't see stale data.
        await ResponseCache.shared.removeAll()

        // Clear offline queue.
        OfflineActionQueue.shared.clearAll()
        OfflineActionQueue.shared.clearOwner()
    }

    private func saveLastUser(_ user: UserPublic) {
        do {
            let data = try JSONEncoder().encode(user)
            UserDefaults.standard.set(data, forKey: lastUserKey)
        } catch {
            // ignore
        }
    }

    private func loadLastUser() -> UserPublic? {
        guard let data = UserDefaults.standard.data(forKey: lastUserKey) else { return nil }
        return try? JSONDecoder().decode(UserPublic.self, from: data)
    }
}
