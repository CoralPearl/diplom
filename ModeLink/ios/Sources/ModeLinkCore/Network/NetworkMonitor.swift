import Foundation
import Network

/// Simple network connectivity monitor ("online/offline") based on `NWPathMonitor`.
///
/// Notes:
/// - This is **not** a guarantee that the backend is reachable.
/// - It is good enough for UX: show offline banner, prevent accidental logouts when offline.
@MainActor
final class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()

    @Published private(set) var isConnected: Bool = true
    @Published private(set) var isExpensive: Bool = false
    @Published private(set) var interfaceName: String? = nil

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    private var started = false

    private init() {
        startIfNeeded()
    }

    func startIfNeeded() {
        guard !started else { return }
        started = true

        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                guard let self else { return }

                self.isConnected = (path.status == .satisfied)
                self.isExpensive = path.isExpensive

                if path.usesInterfaceType(.wifi) {
                    self.interfaceName = "Wi‑Fi"
                } else if path.usesInterfaceType(.cellular) {
                    self.interfaceName = "Cellular"
                } else if path.usesInterfaceType(.wiredEthernet) {
                    self.interfaceName = "Ethernet"
                } else {
                    self.interfaceName = nil
                }
            }
        }

        monitor.start(queue: queue)
    }

    var statusText: String {
        isConnected ? "Онлайн" : "Оффлайн"
    }
}
