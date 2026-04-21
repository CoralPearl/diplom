import Foundation
import Combine
import UIKit

@MainActor
final class BookerModelDetailsViewModel: ObservableObject {
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    @Published var details: ModelDetails? = nil

    let modelId: UUID

    init(modelId: UUID) {
        self.modelId = modelId
    }

    func load() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }

        do {
            let d: ModelDetails = try await APIClient.shared.get("/models/\(modelId.uuidString)")
            self.details = d

            // Prefetch portfolio images (small thumbnails) to make grids feel instant.
            let urls = d.portfolioImages.map { $0.imageUrl }
            let scale = UIScreen.main.scale
            Task.detached(priority: .utility) {
                await ImagePipeline.shared.prefetch(urls: urls, targetSize: CGSize(width: 140, height: 140), scale: scale)
            }
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}
