import SwiftUI

struct NetworkBanner: View {
    @EnvironmentObject private var network: NetworkMonitor

    var body: some View {
        if network.isConnected {
            EmptyView()
        } else {
            HStack(spacing: 10) {
                Image(systemName: "wifi.slash")
                    .imageScale(.medium)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Нет подключения")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text("Показаны сохранённые данные (если доступны).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                Text(network.statusText)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(.orange.opacity(0.12))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(.orange.opacity(0.25), lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .padding(.horizontal)
            .padding(.top, 6)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}
