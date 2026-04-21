import SwiftUI

struct BookerModelDetailsView: View {
    @StateObject private var vm: BookerModelDetailsViewModel

    init(modelId: UUID) {
        _vm = StateObject(wrappedValue: BookerModelDetailsViewModel(modelId: modelId))
    }

    var body: some View {
        Group {
            if vm.isLoading {
                LoadingView(title: "", subtitle: "Загрузка…")
            } else if let error = vm.errorMessage {
                VStack {
                    ErrorBox(message: error)
                    Button("Повторить") { Task { await vm.load() } }
                        .buttonStyle(.bordered)
                }
                .padding()
            } else if let d = vm.details {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        profileSection(d)
                        portfolioSection(d)
                        projectsSection(d)
                    }
                    .padding()
                }
            } else {
                EmptyStateView(title: "Нет данных", subtitle: nil)
            }
        }
        .navigationTitle("Карточка модели")
        .task {
            await vm.load()
        }
        .refreshable {
            await vm.load()
        }
    }

    private func profileSection(_ d: ModelDetails) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(d.fullName.isEmpty ? "(без имени)" : d.fullName)
                .font(.title2.bold())
            Text(d.userEmail)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Divider()

            ProfileKV(title: "Рост", value: d.height.map { "\($0)" })
            ProfileKV(title: "Вес", value: d.weight.map { "\($0)" })
            ProfileKV(title: "Грудь", value: d.bust.map { "\($0)" })
            ProfileKV(title: "Талия", value: d.waist.map { "\($0)" })
            ProfileKV(title: "Бёдра", value: d.hips.map { "\($0)" })
            ProfileKV(title: "Обувь", value: d.shoeSize.map { "\($0)" })
        }
        .padding(12)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func portfolioSection(_ d: ModelDetails) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Портфолио")
                    .font(.headline)
                Spacer()
                Text("\(d.portfolioImages.count)/10")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if d.portfolioImages.isEmpty {
                Text("Нет фото")
                    .foregroundStyle(.secondary)
            } else {
                ReadOnlyPortfolioGrid(images: d.portfolioImages)
            }
        }
    }

    private func projectsSection(_ d: ModelDetails) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Проекты")
                .font(.headline)

            if d.projects.isEmpty {
                Text("Нет проектов")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(d.projects) { p in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(p.title)
                            .font(.subheadline.bold())
                        Text(p.location)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(p.date.formatted(date: .abbreviated, time: .shortened))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .padding(12)
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        }
    }
}

private struct ProfileKV: View {
    let title: String
    let value: String?

    var body: some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value ?? "—")
        }
        .font(.subheadline)
    }
}

private struct ReadOnlyPortfolioGrid: View {
    let images: [PortfolioImage]

    @State private var isViewerPresented: Bool = false
    @State private var viewerIndex: Int = 0

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(Array(images.enumerated()), id: \.element.id) { idx, img in
                CachedAsyncImage(
                    url: img.imageUrl,
                    targetSize: CGSize(width: 140, height: 140),
                    contentMode: .fill,
                    showsProgress: true,
                    failureIcon: "photo"
                )
                .frame(height: 110)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .contentShape(Rectangle())
                .onTapGesture {
                    viewerIndex = idx
                    isViewerPresented = true
                }
            }
        }
        .fullScreenCover(isPresented: $isViewerPresented) {
            PortfolioViewer(images: images, startIndex: viewerIndex)
        }
    }
}
