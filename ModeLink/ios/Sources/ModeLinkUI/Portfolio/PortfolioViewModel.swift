import Foundation
import Combine
import UIKit

enum PortfolioContext {
    case currentModel
    case model(id: UUID)

    var modelId: UUID? {
        switch self {
        case .currentModel: return nil
        case .model(let id): return id
        }
    }

    var title: String {
        switch self {
        case .currentModel: return "Портфолио"
        case .model: return "Портфолио модели"
        }
    }
}

@MainActor
final class PortfolioViewModel: ObservableObject {
    struct UploadPayload {
        let data: Data
        let filename: String
        let mimeType: String
    }

    @Published var images: [PortfolioImage] = []
    @Published var isLoading: Bool = false

    @Published var isUploading: Bool = false
    @Published var uploadProgress: Double? = nil

    @Published var errorMessage: String? = nil

    let context: PortfolioContext

    private var lastUpload: UploadPayload? = nil
    private var lastUploadIdempotencyKey: String? = nil

    init(context: PortfolioContext) {
        self.context = context
    }

    var countText: String {
        "\(images.count)/10"
    }

    var canRetryUpload: Bool {
        lastUpload != nil && !isUploading
    }

    var uploadPercentText: String {
        guard let uploadProgress else { return "" }
        let pct = Int((uploadProgress * 100).rounded())
        return "\(pct)%"
    }

    func load() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }

        do {
            let list: [PortfolioImage]
            if let modelId = context.modelId {
                let query = [URLQueryItem(name: "modelId", value: modelId.uuidString)]
                list = try await APIClient.shared.get("/portfolio", query: query)
            } else {
                list = try await APIClient.shared.get("/portfolio")
            }

            images = list

            // Prefetch thumbnails for smooth scrolling.
            let urls = list.map { $0.imageUrl }
            let scale = UIScreen.main.scale
            Task.detached(priority: .utility) {
                await ImagePipeline.shared.prefetch(urls: urls, targetSize: CGSize(width: 140, height: 140), scale: scale)
            }
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func upload(imageData: Data, filename: String, mimeType: String) async -> Bool {
        errorMessage = nil

        if images.count >= 10 {
            errorMessage = "Лимит 10 фото"
            return false
        }

        let payload = UploadPayload(data: imageData, filename: filename, mimeType: mimeType)
        lastUpload = payload
        let key = UUID().uuidString
        lastUploadIdempotencyKey = key

        return await performUpload(payload: payload, idempotencyKey: key)
    }

    func retryLastUpload() async -> Bool {
        guard let lastUpload else {
            errorMessage = nil
            return false
        }
        let key = lastUploadIdempotencyKey ?? UUID().uuidString
        lastUploadIdempotencyKey = key
        return await performUpload(payload: lastUpload, idempotencyKey: key)
    }

    private func performUpload(payload: UploadPayload, idempotencyKey: String) async -> Bool {
        isUploading = true
        uploadProgress = 0
        defer {
            isUploading = false
            uploadProgress = nil
        }

        do {
            let created = try await APIClient.shared.uploadPortfolioImage(
                imageData: payload.data,
                filename: payload.filename,
                mimeType: payload.mimeType,
                modelId: context.modelId,
                idempotencyKey: idempotencyKey,
                onProgress: { [weak self] p in
                    guard let self else { return }
                    Task { @MainActor in
                        self.uploadProgress = p
                    }
                }
            )
            images.insert(created, at: 0)

            // Warm cache for the new image.
            let scale = UIScreen.main.scale
            Task.detached(priority: .utility) {
                _ = try? await ImagePipeline.shared.image(for: created.imageUrl, targetSize: CGSize(width: 140, height: 140), scale: scale)
            }

            // Success: clear retry payload and key.
            lastUpload = nil
            lastUploadIdempotencyKey = nil
            return true
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            return false
        }
    }

    func delete(image: PortfolioImage) async -> Bool {
        errorMessage = nil
        do {
            let _: OkResponse = try await APIClient.shared.delete("/portfolio/\(image.id.uuidString)")
            images.removeAll { $0.id == image.id }
            return true
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            return false
        }
    }
}
