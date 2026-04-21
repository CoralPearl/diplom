import SwiftUI

struct ManagerModelWorkspaceView: View {
    @StateObject private var vm: BookerModelDetailsViewModel

    let modelId: UUID
    let title: String

    init(modelId: UUID, title: String) {
        self.modelId = modelId
        self.title = title
        _vm = StateObject(wrappedValue: BookerModelDetailsViewModel(modelId: modelId))
    }

    var body: some View {
        TabView {
            NavigationStack {
                Group {
                    if vm.isLoading {
                        LoadingView(title: "", subtitle: "Загрузка…")
                    } else if let error = vm.errorMessage {
                        VStack {
                            ErrorBox(message: error)
                            Button("Повторить") { Task { await vm.load() } }
                                .buttonStyle(.bordered)
                        }
                        .padding()
                    } else if let d = vm.details {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 12) {
                                Text(d.fullName.isEmpty ? "(без имени)" : d.fullName)
                                    .font(.title2.bold())
                                Text(d.userEmail)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)

                                Divider()

                                VStack(spacing: 8) {
                                    ManagerProfileKV(title: "Рост", value: d.height.map { "\($0)" })
                                    ManagerProfileKV(title: "Вес", value: d.weight.map { "\($0)" })
                                    ManagerProfileKV(title: "Грудь", value: d.bust.map { "\($0)" })
                                    ManagerProfileKV(title: "Талия", value: d.waist.map { "\($0)" })
                                    ManagerProfileKV(title: "Бёдра", value: d.hips.map { "\($0)" })
                                    ManagerProfileKV(title: "Обувь", value: d.shoeSize.map { "\($0)" })
                                }
                                .padding(12)
                                .background(.thinMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                                Text("Используй вкладки ниже для проектов и портфолио")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                            .padding()
                        }
                    } else {
                        EmptyStateView(title: "Нет данных", subtitle: nil)
                    }
                }
                .navigationTitle(title)
                .task {
                    await vm.load()
                }
                .refreshable {
                    await vm.load()
                }
            }
            .tabItem { Label("Профиль", systemImage: "person") }

            ProjectsView(context: .model(id: modelId))
                .tabItem { Label("Проекты", systemImage: "calendar") }

            PortfolioView(context: .model(id: modelId))
                .tabItem { Label("Портфолио", systemImage: "photo.on.rectangle") }
        }
    }
}

private struct ManagerProfileKV: View {
    let title: String
    let value: String?

    var body: some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value ?? "—")
        }
        .font(.subheadline)
    }
}
