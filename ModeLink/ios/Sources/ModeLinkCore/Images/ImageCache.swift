import Foundation
import UIKit
import CryptoKit

/// In-memory + on-disk image cache.
///
/// - Memory cache uses `NSCache` (auto-evicts on memory pressure).
/// - Disk cache stores JPEG files in the app's `Caches/ModeLinkImageCache/` directory.
/// - Disk cache has a **size cap** with an LRU-like eviction strategy:
///   - We "touch" a file (update modification date) when it is used.
///   - When the folder grows above the limit, we delete the **oldest** files until under the target.
actor ImageCache {
    static let shared = ImageCache()

    private let memory = NSCache<NSString, UIImage>()
    private let fileManager = FileManager.default
    private let folderURL: URL

    /// Disk cache limit.
    /// You can tune this based on device/storage expectations.
    private let diskByteLimit: Int = 200 * 1024 * 1024 // 200MB

    /// When evicting, trim to this size to avoid thrashing.
    private let diskTrimTo: Int = 180 * 1024 * 1024 // 180MB

    init() {
        // Reasonable defaults for a portfolio app.
        memory.countLimit = 200
        memory.totalCostLimit = 50 * 1024 * 1024 // ~50MB

        let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        folderURL = caches.appendingPathComponent("ModeLinkImageCache", isDirectory: true)
        try? fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true)

        // Housekeeping on startup.
        Task.detached(priority: .utility) { [folderURL] in
            // Just ensure folder exists.
            try? FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        }

        Task {
            await enforceDiskLimitIfNeeded()
        }
    }

    func get(_ key: String) async -> UIImage? {
        if let img = memory.object(forKey: key as NSString) {
            // Touch on disk to keep LRU roughly in sync.
            touchFile(for: key)
            return img
        }

        let url = fileURL(for: key)
        guard fileManager.fileExists(atPath: url.path) else { return nil }

        do {
            let data = try await Task.detached(priority: .utility) {
                try Data(contentsOf: url)
            }.value

            guard let img = UIImage(data: data) else { return nil }
            memory.setObject(img, forKey: key as NSString, cost: data.count)

            // Mark as recently used.
            touchFileURL(url)
            return img
        } catch {
            return nil
        }
    }

    func set(_ image: UIImage, for key: String) async {
        let data = image.jpegData(compressionQuality: 0.9) ?? image.pngData()
        let cost = data?.count ?? 1
        memory.setObject(image, forKey: key as NSString, cost: cost)

        guard let data else { return }
        let url = fileURL(for: key)

        // Disk write off the main thread.
        _ = try? await Task.detached(priority: .utility) {
            try data.write(to: url, options: [.atomic])
        }.value

        // Keep within disk budget.
        await enforceDiskLimitIfNeeded()
    }

    func remove(_ key: String) async {
        memory.removeObject(forKey: key as NSString)
        let url = fileURL(for: key)
        _ = try? await Task.detached(priority: .utility) {
            try? FileManager.default.removeItem(at: url)
        }.value
    }

    func removeAll() async {
        memory.removeAllObjects()
        let folder = folderURL
        _ = try? await Task.detached(priority: .utility) {
            let fm = FileManager.default
            guard let files = try? fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil) else { return }
            for f in files {
                try? fm.removeItem(at: f)
            }
        }.value
    }

    // MARK: - Disk LRU

    private func touchFile(for key: String) {
        let url = fileURL(for: key)
        touchFileURL(url)
    }

    private func touchFileURL(_ url: URL) {
        _ = Task.detached(priority: .utility) {
            try? FileManager.default.setAttributes([.modificationDate: Date()], ofItemAtPath: url.path)
        }
    }

    private func enforceDiskLimitIfNeeded() async {
        // Collect disk usage info off-thread.
        let folder = folderURL
        let infos: [(url: URL, size: Int, date: Date)] = (try? await Task.detached(priority: .utility) {
            let fm = FileManager.default
            let keys: Set<URLResourceKey> = [.fileSizeKey, .contentModificationDateKey]
            guard let files = try? fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: Array(keys), options: [.skipsHiddenFiles]) else {
                return []
            }

            return files.compactMap { url -> (URL, Int, Date)? in
                guard (try? url.resourceValues(forKeys: keys)) != nil else { return nil }
                let values = try? url.resourceValues(forKeys: keys)
                let size = values?.fileSize ?? 0
                let date = values?.contentModificationDate ?? Date.distantPast
                return (url, size, date)
            }
        }.value) ?? []

        var total = infos.reduce(0) { $0 + $1.size }
        guard total > diskByteLimit else { return }

        // Evict oldest first.
        let sorted = infos.sorted { $0.date < $1.date }
        var toRemove: [URL] = []

        for info in sorted {
            toRemove.append(info.url)
            total -= info.size
            if total <= diskTrimTo {
                break
            }
        }

        guard !toRemove.isEmpty else { return }

        _ = try? await Task.detached(priority: .utility) {
            let fm = FileManager.default
            for url in toRemove {
                try? fm.removeItem(at: url)
            }
        }.value
    }

    private func fileURL(for key: String) -> URL {
        let hashed = key.sha256
        return folderURL
            .appendingPathComponent(hashed)
            .appendingPathExtension("jpg")
    }
}

private extension String {
    var sha256: String {
        let data = Data(self.utf8)
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
