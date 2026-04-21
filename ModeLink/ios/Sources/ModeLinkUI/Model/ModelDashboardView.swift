import SwiftUI

struct ModelDashboardView: View {
    var body: some View {
        TabView {
            ModelProfileView()
                .tabItem { Label("Профиль", systemImage: "person") }

            ProjectsView(context: .currentModel)
                .tabItem { Label("Проекты", systemImage: "calendar") }

            PortfolioView(context: .currentModel)
                .tabItem { Label("Портфолио", systemImage: "photo.on.rectangle") }

            SettingsView()
                .tabItem { Label("Настройки", systemImage: "gear") }
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        NavigationStack {
            Form {
                Section("Аккаунт") {
                    Text(appState.me?.email ?? "")
                    Text(appState.me?.role.titleRu ?? "")
                        .foregroundStyle(.secondary)
                }

                Section {
                    Button(role: .destructive) {
                        Task { await appState.logout() }
                    } label: {
                        Text("Выйти")
                    }
                }
            }
            .navigationTitle("Настройки")
        }
    }
}
