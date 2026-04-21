import Foundation
import UIKit

enum ImagePipelineError: LocalizedError {
    case http(Int)
    case decodeFailed

    var errorDescription: String? {
        switch self {
        case .http(let code):
            return "HTTP error: \(code)"
        case .decodeFailed:
            return "Image decode failed"
        }
    }
}

/// Centralized image loader with caching + request de-duplication.
actor ImagePipeline {
    static let shared = ImagePipeline(cache: .shared)

    private let cache: ImageCache
    private var inFlight: [String: Task<UIImage, Error>] = [:]

    init(cache: ImageCache) {
        self.cache = cache
    }

    func image(for url: URL, targetSize: CGSize?, scale: CGFloat) async throws -> UIImage {
        let key = cacheKey(url: url, targetSize: targetSize, scale: scale)

        if let cached = await cache.get(key) {
            return cached
        }

        if let task = inFlight[key] {
            return try await task.value
        }

        let task = Task<UIImage, Error> {
            let data = try await Self.downloadData(from: url)
            let uiImage: UIImage?

            if let targetSize {
                uiImage = ImageDownsampler.downsample(data: data, to: targetSize, scale: scale) ?? UIImage(data: data)
            } else {
                uiImage = UIImage(data: data)
            }

            guard let uiImage else {
                throw ImagePipelineError.decodeFailed
            }

            await cache.set(uiImage, for: key)
            return uiImage
        }

        inFlight[key] = task
        defer { inFlight[key] = nil }

        return try await task.value
    }

    func prefetch(urls: [URL], targetSize: CGSize?, scale: CGFloat) async {
        let unique = Array(Set(urls))
        await withTaskGroup(of: Void.self) { group in
            for url in unique {
                group.addTask {
                    _ = try? await ImagePipeline.shared.image(for: url, targetSize: targetSize, scale: scale)
                }
            }
        }
    }

    private func cacheKey(url: URL, targetSize: CGSize?, scale: CGFloat) -> String {
        if let targetSize {
            let w = Int(targetSize.width * scale)
            let h = Int(targetSize.height * scale)
            return "\(url.absoluteString)|\(w)x\(h)"
        }
        return url.absoluteString
    }

    private static func downloadData(from url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.cachePolicy = .returnCacheDataElseLoad

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse {
            guard (200...299).contains(http.statusCode) else {
                throw ImagePipelineError.http(http.statusCode)
            }
        }
        return data
    }
}
