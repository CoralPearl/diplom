import Foundation

enum AdminUsersSortOption: String, CaseIterable, Identifiable {
    case newest
    case emailAZ
    case emailZA
    case roleAZ
    case roleZA

    var id: String { rawValue }

    var title: String {
        switch self {
        case .newest: return "Сначала новые"
        case .emailAZ: return "Email: A → Z"
        case .emailZA: return "Email: Z → A"
        case .roleAZ: return "Роль: A → Z"
        case .roleZA: return "Роль: Z → A"
        }
    }

    var sortBy: String {
        switch self {
        case .newest: return "createdAt"
        case .emailAZ, .emailZA: return "email"
        case .roleAZ, .roleZA: return "role"
        }
    }

    var order: String {
        switch self {
        case .newest: return "desc"
        case .emailAZ: return "asc"
        case .emailZA: return "desc"
        case .roleAZ: return "asc"
        case .roleZA: return "desc"
        }
    }
}

enum AdminUsersBlockedFilter: String, CaseIterable, Identifiable {
    case all
    case active
    case blocked

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "Все"
        case .active: return "Активные"
        case .blocked: return "Заблокированные"
        }
    }
}

@MainActor
final class AdminUsersViewModel: ObservableObject {
    @Published var isLoading: Bool = false
    @Published var isLoadingMore: Bool = false
    @Published var errorMessage: String? = nil
    @Published var users: [AdminUser] = []

    @Published var query: String = ""
    @Published var sort: AdminUsersSortOption = .newest
    @Published var roleFilter: Role? = nil
    @Published var blockedFilter: AdminUsersBlockedFilter = .all

    private var page: Int = 1
    private let limit: Int = 20
    private var totalPages: Int = 1

    private var debounceTask: Task<Void, Never>? = nil

    func initialLoad() async {
        if users.isEmpty {
            await reload()
        }
    }

    func scheduleReload() {
        debounceTask?.cancel()
        debounceTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 350_000_000)
            await self?.reload()
        }
    }

    func reload() async {
        debounceTask?.cancel()
        errorMessage = nil
        isLoading = true
        isLoadingMore = false
        page = 1
        totalPages = 1
        defer { isLoading = false }

        do {
            let resp: PagedResponse<AdminUser> = try await APIClient.shared.get(
                "/admin/users",
                query: makeQueryItems(page: 1)
            )
            users = resp.items
            page = resp.page
            totalPages = resp.totalPages
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func loadMoreIfNeeded(currentItem item: AdminUser) async {
        guard !isLoading, !isLoadingMore else { return }
        guard page < totalPages else { return }
        guard users.last?.id == item.id else { return }

        isLoadingMore = true
        errorMessage = nil
        defer { isLoadingMore = false }

        let nextPage = page + 1
        do {
            let resp: PagedResponse<AdminUser> = try await APIClient.shared.get(
                "/admin/users",
                query: makeQueryItems(page: nextPage)
            )

            let existing = Set(users.map { $0.id })
            let newItems = resp.items.filter { !existing.contains($0.id) }
            users.append(contentsOf: newItems)

            page = resp.page
            totalPages = resp.totalPages
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func replaceUser(_ updated: AdminUser) {
        if let idx = users.firstIndex(where: { $0.id == updated.id }) {
            users[idx] = updated
        }
    }

    private func makeQueryItems(page: Int) -> [URLQueryItem] {
        var q: [URLQueryItem] = [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "sortBy", value: sort.sortBy),
            URLQueryItem(name: "order", value: sort.order),
        ]

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            q.append(URLQueryItem(name: "q", value: trimmed))
        }

        if let role = roleFilter {
            q.append(URLQueryItem(name: "role", value: role.rawValue))
        }

        switch blockedFilter {
        case .all:
            break
        case .active:
            q.append(URLQueryItem(name: "blocked", value: "false"))
        case .blocked:
            q.append(URLQueryItem(name: "blocked", value: "true"))
        }

        return q
    }
}
