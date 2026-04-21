import SwiftUI

struct AdminDashboardView: View {
    var body: some View {
        TabView {
            ModelsListView(mode: .admin)
                .tabItem { Label("Модели", systemImage: "person.3") }

            AdminUsersView()
                .tabItem { Label("Пользователи", systemImage: "person.crop.circle") }
        }
    }
}
