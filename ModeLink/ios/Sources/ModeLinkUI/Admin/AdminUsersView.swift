import SwiftUI

struct AdminUsersView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var vm = AdminUsersViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if vm.isLoading && vm.users.isEmpty {
                    LoadingView(title: "", subtitle: "Загрузка пользователей…")
                } else if vm.users.isEmpty {
                    EmptyStateView(title: emptyTitle, subtitle: emptySubtitle)
                } else {
                    List {
                        ForEach(vm.users) { u in
                            NavigationLink {
                                AdminUserDetailView(
                                    user: u,
                                    currentAdminId: appState.me?.id
                                ) { updated in
                                    vm.replaceUser(updated)
                                }
                            } label: {
                                AdminUserRow(user: u, isMe: u.id == appState.me?.id)
                            }
                            .task {
                                await vm.loadMoreIfNeeded(currentItem: u)
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
            .navigationTitle("Пользователи")
            .searchable(text: $vm.query, prompt: "Поиск по email")
            .onChange(of: vm.query) { _ in
                vm.scheduleReload()
            }
            .onChange(of: vm.sort) { _ in
            }
            .onChange(of: vm.roleFilter?.rawValue) { _ in
            }
            .onChange(of: vm.blockedFilter) { _ in
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    filtersMenu
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

    private var filtersMenu: some View {
        Menu {
            Section("Сортировка") {
                Picker("Сортировка", selection: $vm.sort) {
                    ForEach(AdminUsersSortOption.allCases) { opt in
                        Text(opt.title).tag(opt)
                    }
                }
            }

            Section("Роль") {
                Button {
                    vm.roleFilter = nil
                } label: {
                    if vm.roleFilter == nil {
                        Label("Все роли", systemImage: "checkmark")
                    } else {
                        Text("Все роли")
                    }
                }

                ForEach(Role.allCases) { role in
                    Button {
                        vm.roleFilter = role
                    } label: {
                        if vm.roleFilter == role {
                            Label(role.titleRu, systemImage: "checkmark")
                        } else {
                            Text(role.titleRu)
                        }
                    }
                }
            }

            Section("Статус") {
                Picker("Статус", selection: $vm.blockedFilter) {
                    ForEach(AdminUsersBlockedFilter.allCases) { f in
                        Text(f.title).tag(f)
                    }
                }
            }
        } label: {
            Image(systemName: "slider.horizontal.3")
        }
        .accessibilityLabel("Фильтры")
    }

    private var emptyTitle: String {
        let q = vm.query.trimmingCharacters(in: .whitespacesAndNewlines)
        if q.isEmpty {
            return "Пользователей нет"
        }
        return "Ничего не найдено"
    }

    private var emptySubtitle: String {
        let q = vm.query.trimmingCharacters(in: .whitespacesAndNewlines)
        if q.isEmpty {
            return "Создай пользователей через регистрацию или скрипт create-admin"
        }
        return "Попробуй другой запрос"
    }
}

private struct AdminUserRow: View {
    let user: AdminUser
    let isMe: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(user.email)
                    .font(.headline)
                    .lineLimit(1)

                if isMe {
                    Text("Это ты")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                }

                Spacer()
            }

            HStack(spacing: 10) {
                Text(user.role.titleRu)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if user.isBlocked {
                    Label("Заблокирован", systemImage: "hand.raised.fill")
                        .font(.subheadline)
                        .foregroundStyle(.red)
                } else {
                    Label("Активен", systemImage: "checkmark.seal")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            if let profile = user.modelProfile, user.role == .model {
                Text(profile.fullName.isEmpty ? "(профиль без имени)" : profile.fullName)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
