import Foundation

enum ModelsSortOption: String, CaseIterable, Identifiable {
    case newest
    case nameAZ
    case nameZA
    case mostPhotos
    case mostProjects

    var id: String { rawValue }

    var title: String {
        switch self {
        case .newest: return "Сначала новые"
        case .nameAZ: return "Имя: A → Z"
        case .nameZA: return "Имя: Z → A"
        case .mostPhotos: return "Больше фото"
        case .mostProjects: return "Больше проектов"
        }
    }

    var sortBy: String {
        switch self {
        case .newest: return "createdAt"
        case .nameAZ, .nameZA: return "fullName"
        case .mostPhotos: return "portfolioCount"
        case .mostProjects: return "projectsCount"
        }
    }

    var order: String {
        switch self {
        case .newest: return "desc"
        case .nameAZ: return "asc"
        case .nameZA: return "desc"
        case .mostPhotos, .mostProjects: return "desc"
        }
    }
}

@MainActor
final class ModelsListViewModel: ObservableObject {
    @Published var isLoading: Bool = false
    @Published var isLoadingMore: Bool = false
    @Published var errorMessage: String? = nil
    @Published var models: [ModelsListItem] = []

    @Published var query: String = ""
    @Published var sort: ModelsSortOption = .newest

    private var page: Int = 1
    private let limit: Int = 20
    private var totalPages: Int = 1

    private var debounceTask: Task<Void, Never>? = nil

    func initialLoad() async {
        if models.isEmpty {
            await reload()
        }
    }

    func scheduleReload() {
        debounceTask?.cancel()
        debounceTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 350_000_000) // 0.35s debounce
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
            let resp: PagedResponse<ModelsListItem> = try await APIClient.shared.get(
                "/models",
                query: makeQueryItems(page: 1)
            )
            models = resp.items
            page = resp.page
            totalPages = resp.totalPages
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func loadMoreIfNeeded(currentItem item: ModelsListItem) async {
        guard !isLoading, !isLoadingMore else { return }
        guard page < totalPages else { return }
        guard models.last?.id == item.id else { return }

        isLoadingMore = true
        errorMessage = nil
        defer { isLoadingMore = false }

        let nextPage = page + 1
        do {
            let resp: PagedResponse<ModelsListItem> = try await APIClient.shared.get(
                "/models",
                query: makeQueryItems(page: nextPage)
            )
            // Append (avoid duplicates)
            let existing = Set(models.map { $0.id })
            let newItems = resp.items.filter { !existing.contains($0.id) }
            models.append(contentsOf: newItems)

            page = resp.page
            totalPages = resp.totalPages
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
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

        return q
    }
}
