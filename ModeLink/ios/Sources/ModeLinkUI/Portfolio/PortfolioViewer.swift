import SwiftUI

struct PortfolioViewer: View {
    let images: [PortfolioImage]
    let startIndex: Int

    @Environment(\.dismiss) private var dismiss
    @State private var selection: Int

    init(images: [PortfolioImage], startIndex: Int) {
        self.images = images
        self.startIndex = startIndex
        let safe = max(0, min(startIndex, max(images.count - 1, 0)))
        _selection = State(initialValue: safe)
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                TabView(selection: $selection) {
                    ForEach(Array(images.enumerated()), id: \.element.id) { idx, img in
                        ZStack {
                            Color.black.ignoresSafeArea()

                            CachedAsyncImage(
                                url: img.imageUrl,
                                targetSize: geo.size,
                                contentMode: .fit,
                                showsProgress: true,
                                failureIcon: "photo"
                            )
                        }
                        .tag(idx)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .automatic))
            }
            .navigationTitle(images.isEmpty ? "" : "\(selection + 1)/\(images.count)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Закрыть") { dismiss() }
                }
            }
        }
    }
}
