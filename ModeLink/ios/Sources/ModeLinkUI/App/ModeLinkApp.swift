import SwiftUI

@main
struct ModeLinkApp: App {
    @StateObject private var appState = AppState.shared
    @StateObject private var network = NetworkMonitor.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .environmentObject(network)
                .onAppear {
                    network.startIfNeeded()
                    OfflineSyncEngine.shared.start()
                    appState.bootstrap()
                }
        }
    }
}
