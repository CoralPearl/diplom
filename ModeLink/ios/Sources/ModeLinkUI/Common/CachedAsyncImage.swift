import SwiftUI
import UIKit

/// A lightweight replacement for `AsyncImage` with:
/// - Memory + disk cache
/// - Downsampling to target size
/// - Consistent placeholders (no flicker on reload)
struct CachedAsyncImage: View {
    let url: URL?
    let targetSize: CGSize?

    var contentMode: ContentMode = .fill
    var showsProgress: Bool = true
    var failureIcon: String = "exclamationmark.triangle"

    @StateObject private var loader = CachedImageLoader()

    var body: some View {
        ZStack {
            if let img = loader.image {
                Image(uiImage: img)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else if loader.isLoading {
                Rectangle().opacity(0.1)
                    .overlay {
                        if showsProgress {
                            ProgressView()
                        }
                    }
            } else if loader.didFail {
                Rectangle().opacity(0.1)
                    .overlay {
                        Image(systemName: failureIcon)
                    }
            } else {
                Rectangle().opacity(0.1)
            }
        }
        .task(id: loader.taskId(url: url, targetSize: targetSize)) {
            await loader.load(url: url, targetSize: targetSize)
        }
    }
}

@MainActor
final class CachedImageLoader: ObservableObject {
    @Published var image: UIImage? = nil
    @Published var isLoading: Bool = false
    @Published var didFail: Bool = false

    private var currentKey: String? = nil

    func taskId(url: URL?, targetSize: CGSize?) -> String {
        guard let url else { return "nil" }
        if let targetSize {
            let scale = UIScreen.main.scale
            let w = Int(targetSize.width * scale)
            let h = Int(targetSize.height * scale)
            return "\(url.absoluteString)|\(w)x\(h)"
        }
        return url.absoluteString
    }

    func load(url: URL?, targetSize: CGSize?) async {
        didFail = false
        guard let url else {
            image = nil
            currentKey = nil
            return
        }

        let key = taskId(url: url, targetSize: targetSize)
        if currentKey != key {
            // URL/size changed – avoid showing a wrong previous image.
            image = nil
        }
        currentKey = key

        isLoading = true
        defer { isLoading = false }

        do {
            let img = try await ImagePipeline.shared.image(for: url, targetSize: targetSize, scale: UIScreen.main.scale)
            // If task got superseded, ignore.
            guard currentKey == key else { return }
            image = img
        } catch {
            guard currentKey == key else { return }
            didFail = true
        }
    }
}
