import SwiftUI

enum ModelsListMode {
    case booker
    case manager
    case admin

    var title: String {
        switch self {
        case .booker: return "Модели"
        case .manager: return "Модели"
        case .admin: return "Модели"
        }
    }

    var canEdit: Bool {
        switch self {
        case .booker: return false
        case .manager, .admin: return true
        }
    }
}

struct ModelsListView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var vm = ModelsListViewModel()

    let mode: ModelsListMode

    var body: some View {
        NavigationStack {
            Group {
                if vm.isLoading && vm.models.isEmpty {
                    LoadingView(title: "", subtitle: "Загрузка моделей…")
                } else if vm.models.isEmpty {
                    EmptyStateView(
                        title: emptyTitle,
                        subtitle: emptySubtitle
                    )
                } else {
                    List {
                        ForEach(vm.models) { m in
                            NavigationLink {
                                if mode.canEdit {
                                    ManagerModelWorkspaceView(modelId: m.id, title: m.fullName)
                                } else {
                                    BookerModelDetailsView(modelId: m.id)
                                }
                            } label: {
                                ModelListRow(item: m)
                            }
                            .task {
                                await vm.loadMoreIfNeeded(currentItem: m)
                            }
                        }

                        if vm.isLoadingMore {
                            HStack {
                                Spacer()
                                ProgressView()
                                Spacer()
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle(mode.title)
            .searchable(text: $vm.query, prompt: "Поиск по имени или email")
            .onChange(of: vm.query) { _ in
                vm.scheduleReload()
            }
            .onChange(of: vm.sort) { _ in
                Task { await vm.reload() }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    sortMenu
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Выйти", role: .destructive) {
                        Task { await appState.logout() }
                    }
                }
            }
            .task {
                await vm.initialLoad()
            }
            .refreshable {
                await vm.reload()
            }
            .safeAreaInset(edge: .bottom) {
                if let error = vm.errorMessage {
                    ErrorBox(message: error)
                        .padding()
                        .background(.ultraThinMaterial)
                }
            }
        }
    }

    private var sortMenu: some View {
        Menu {
            Picker("Сортировка", selection: $vm.sort) {
                ForEach(ModelsSortOption.allCases) { opt in
                    Text(opt.title).tag(opt)
                }
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
        }
        .accessibilityLabel("Сортировка")
    }

    private var emptyTitle: String {
        let q = vm.query.trimmingCharacters(in: .whitespacesAndNewlines)
        if q.isEmpty {
            return "Пока нет моделей"
        }
        return "Ничего не найдено"
    }

    private var emptySubtitle: String {
        let q = vm.query.trimmingCharacters(in: .whitespacesAndNewlines)
        if q.isEmpty {
            return "Добавь пользователя с ролью model"
        }
        return "Попробуй другой запрос"
    }
}

private struct ModelListRow: View {
    let item: ModelsListItem

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(item.fullName.isEmpty ? "(без имени)" : item.fullName)
                .font(.headline)
            Text(item.userEmail)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Label("\(item.portfolioCount)", systemImage: "photo")
                Label("\(item.projectsCount)", systemImage: "calendar")
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}
