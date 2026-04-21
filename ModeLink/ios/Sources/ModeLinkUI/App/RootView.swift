import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var network: NetworkMonitor

    var body: some View {
        Group {
            if appState.isBootstrapping {
                LoadingView(title: "ModeLink", subtitle: "Загрузка…")
            } else if !appState.isAuthenticated {
                AuthFlowView()
            } else if appState.me == nil {
                OfflineGateView()
            } else {
                switch appState.me?.role {
                case .model:
                    ModelDashboardView()
                case .booker:
                    ModelsListView(mode: .booker)
                case .manager:
                    ModelsListView(mode: .manager)
                case .admin:
                    AdminDashboardView()
                case .none:
                    OfflineGateView()
                }
            }
        }
        .animation(.default, value: network.isConnected)
        .safeAreaInset(edge: .top) {
            NetworkBanner()
                .environmentObject(network)
        }
    }
}

private struct OfflineGateView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var network: NetworkMonitor

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.system(size: 52))
                .foregroundStyle(.secondary)

            Text("Не удалось загрузить профиль")
                .font(.title3)
                .fontWeight(.semibold)

            Text(network.isConnected
                 ? "Попробуй обновить позже."
                 : "Ты сейчас оффлайн. Подключись к интернету, чтобы продолжить.")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal)

            Button(role: .destructive) {
                Task { await appState.logout() }
            } label: {
                Text("Выйти")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal)

            Spacer()
        }
    }
}
