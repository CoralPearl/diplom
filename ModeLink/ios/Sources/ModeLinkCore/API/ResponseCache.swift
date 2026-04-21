import Foundation
import CryptoKit

/// Very small JSON response cache for offline-friendly UX.
///
/// - Stores raw response data for GET requests in `Caches/ModeLinkResponseCache/`.
/// - Key is hashed (SHA256) to create stable filenames.
/// - Intended for *read* endpoints only.
actor ResponseCache {
    static let shared = ResponseCache()

    private let fm = FileManager.default
    private let folderURL: URL

    /// Default max age for cached responses.
    /// If a cache entry is older, it will be ignored.
    private let defaultMaxAge: TimeInterval = 7 * 24 * 60 * 60 // 7 days

    init() {
        let caches = fm.urls(for: .cachesDirectory, in: .userDomainMask).first!
        folderURL = caches.appendingPathComponent("ModeLinkResponseCache", isDirectory: true)
        try? fm.createDirectory(at: folderURL, withIntermediateDirectories: true)
    }

    func store(_ data: Data, for key: String) async {
        let url = fileURL(for: key)
        _ = try? await Task.detached(priority: .utility) {
            try data.write(to: url, options: [.atomic])
        }.value
    }

    func load(for key: String, maxAge: TimeInterval? = nil) async -> Data? {
        let url = fileURL(for: key)
        guard fm.fileExists(atPath: url.path) else { return nil }

        let ageLimit = maxAge ?? defaultMaxAge

        // Validate age
        if let attrs = try? fm.attributesOfItem(atPath: url.path),
           let modified = attrs[.modificationDate] as? Date {
            let age = Date().timeIntervalSince(modified)
            if age > ageLimit {
                return nil
            }
        }

        do {
            let data = try await Task.detached(priority: .utility) {
                try Data(contentsOf: url)
            }.value
            return data
        } catch {
            return nil
        }
    }

    func removeAll() async {
        let folder = folderURL
        _ = try? await Task.detached(priority: .utility) {
            let fm = FileManager.default
            guard let files = try? fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil) else { return }
            for f in files {
                try? fm.removeItem(at: f)
            }
        }.value
    }

    private func fileURL(for key: String) -> URL {
        let hashed = key.sha256
        return folderURL.appendingPathComponent(hashed).appendingPathExtension("json")
    }
}

private extension String {
    var sha256: String {
        let data = Data(self.utf8)
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
