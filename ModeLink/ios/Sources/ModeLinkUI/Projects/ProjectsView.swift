import SwiftUI

struct ProjectsView: View {
    @StateObject private var vm: ProjectsViewModel

    @State private var showingCreate: Bool = false
    @State private var editing: Project? = nil
    @State private var deleteCandidate: Project? = nil

    init(context: ProjectsContext) {
        _vm = StateObject(wrappedValue: ProjectsViewModel(context: context))
    }

    var body: some View {
        NavigationStack {
            Group {
                if vm.isLoading {
                    LoadingView(title: "", subtitle: "Загрузка проектов…")
                } else if vm.projects.isEmpty && vm.pending.isEmpty {
                    EmptyStateView(title: "Нет проектов", subtitle: "Добавь первый проект")
                } else {
                    List {
                        if !vm.pending.isEmpty {
                            Section("Ожидает синхронизации") {
                                ForEach(vm.pending) { p in
                                    PendingProjectRow(item: p)
                                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                            if p.status == .failed {
                                                Button {
                                                    OfflineActionQueue.shared.markPending(id: p.id)
                                                    OfflineSyncEngine.shared.kick()
                                                } label: {
                                                    Label("Повторить", systemImage: "arrow.clockwise")
                                                }
                                            }

                                            Button(role: .destructive) {
                                                OfflineActionQueue.shared.remove(id: p.id)
                                            } label: {
                                                Label("Убрать", systemImage: "trash")
                                            }
                                        }
                                }
                            }
                        }

                        ForEach(vm.projects) { p in
                            ProjectRow(project: p)
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button {
                                        editing = p
                                    } label: {
                                        Label("Изменить", systemImage: "pencil")
                                    }

                                    Button(role: .destructive) {
                                        deleteCandidate = p
                                    } label: {
                                        Label("Удалить", systemImage: "trash")
                                    }
                                }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle(vm.context.title)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingCreate = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .task {
                await vm.load()
            }
            .refreshable {
                await vm.load()
            }
            .safeAreaInset(edge: .bottom) {
                if let error = vm.errorMessage {
                    ErrorBox(message: error)
                        .padding()
                        .background(.ultraThinMaterial)
                }
            }
            .sheet(isPresented: $showingCreate) {
                ProjectEditorView(mode: .create) { title, date, location in
                    let ok = await vm.create(title: title, date: date, location: location)
                    return ok ? nil : (vm.errorMessage ?? "Не удалось создать")
                }
            }
            .sheet(item: $editing) { project in
                ProjectEditorView(mode: .edit(project)) { title, date, location in
                    let ok = await vm.update(project: project, title: title, date: date, location: location)
                    return ok ? nil : (vm.errorMessage ?? "Не удалось сохранить")
                }
            }
            .alert("Удалить проект?", isPresented: Binding(get: { deleteCandidate != nil }, set: { if !$0 { deleteCandidate = nil } })) {
                Button("Удалить", role: .destructive) {
                    guard let p = deleteCandidate else { return }
                    Task {
                        _ = await vm.delete(project: p)
                        deleteCandidate = nil
                    }
                }
                Button("Отмена", role: .cancel) {
                    deleteCandidate = nil
                }
            } message: {
                Text(deleteCandidate?.title ?? "")
            }
        }
    }
}

private struct PendingProjectRow: View {
    let item: ProjectsViewModel.PendingProject

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(item.title)
                    .font(.headline)

                Spacer()

                switch item.status {
                case .pending:
                    Label("В очереди", systemImage: "clock")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                case .failed:
                    Label("Ошибка", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Text(item.location)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(item.date.formatted(date: .abbreviated, time: .shortened))
                .font(.footnote)
                .foregroundStyle(.secondary)

            if item.status == .failed, let msg = item.lastError {
                Text(msg)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct ProjectRow: View {
    let project: Project

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(project.title)
                .font(.headline)

            Text(project.location)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(project.date.formatted(date: .abbreviated, time: .shortened))
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}
