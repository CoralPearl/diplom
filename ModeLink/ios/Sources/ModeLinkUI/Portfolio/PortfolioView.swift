import SwiftUI
import PhotosUI
import UIKit

struct PortfolioView: View {
    @EnvironmentObject private var network: NetworkMonitor

    @StateObject private var vm: PortfolioViewModel

    @State private var pickedItem: PhotosPickerItem? = nil
    @State private var deleteCandidate: PortfolioImage? = nil

    // Fullscreen viewer
    @State private var isViewerPresented: Bool = false
    @State private var viewerIndex: Int = 0

    init(context: PortfolioContext) {
        _vm = StateObject(wrappedValue: PortfolioViewModel(context: context))
    }

    var body: some View {
        NavigationStack {
            Group {
                if vm.isLoading {
                    LoadingView(title: "", subtitle: "Загрузка портфолио…")
                } else if vm.images.isEmpty {
                    EmptyStateView(title: "Нет фото", subtitle: "Добавь до 10 фотографий")
                } else {
                    ScrollView {
                        PortfolioGrid(
                            images: vm.images,
                            onTap: { idx in
                                viewerIndex = idx
                                isViewerPresented = true
                            },
                            onLongPressDelete: { image in
                                deleteCandidate = image
                            }
                        )
                        .padding()
                    }
                }
            }
            .navigationTitle(vm.context.title)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Text(vm.countText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    PhotosPicker(selection: $pickedItem, matching: .images) {
                        Image(systemName: "plus")
                    }
                    .disabled(vm.isUploading || vm.images.count >= 10 || !network.isConnected)
                }
            }
            .task {
                await vm.load()
            }
            .refreshable {
                await vm.load()
            }
            .onChange(of: pickedItem) { newValue in
                guard let newValue else { return }
                Task {
                    await handlePickedItem(newValue)
                }
            }
            .overlay {
                if vm.isUploading {
                    UploadProgressOverlay(progress: vm.uploadProgress ?? 0, percentText: vm.uploadPercentText)
                }
            }
            .safeAreaInset(edge: .bottom) {
                if let error = vm.errorMessage {
                    ErrorBox(
                        message: error,
                        actionTitle: vm.canRetryUpload ? "Повторить" : nil,
                        action: vm.canRetryUpload ? {
                            Task { _ = await vm.retryLastUpload() }
                        } : nil
                    )
                    .padding()
                    .background(.ultraThinMaterial)
                }
            }
            .alert("Удалить фото?", isPresented: Binding(get: { deleteCandidate != nil }, set: { if !$0 { deleteCandidate = nil } })) {
                Button("Удалить", role: .destructive) {
                    guard let img = deleteCandidate else { return }
                    Task {
                        _ = await vm.delete(image: img)
                        deleteCandidate = nil
                    }
                }
                Button("Отмена", role: .cancel) { deleteCandidate = nil }
            }
            .fullScreenCover(isPresented: $isViewerPresented) {
                PortfolioViewer(images: vm.images, startIndex: viewerIndex)
            }
        }
    }

    private func handlePickedItem(_ item: PhotosPickerItem) async {
        pickedItem = nil

        if !network.isConnected {
            vm.errorMessage = "Нет подключения к интернету"
            return
        }

        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                vm.errorMessage = "Не удалось прочитать изображение"
                return
            }

            // Convert to JPEG to have a stable upload format.
            let image = UIImage(data: data)
            let jpeg = image?.jpegData(compressionQuality: 0.9) ?? data

            let _ = await vm.upload(
                imageData: jpeg,
                filename: "photo.jpg",
                mimeType: "image/jpeg"
            )
        } catch {
            vm.errorMessage = error.localizedDescription
        }
    }
}

private struct UploadProgressOverlay: View {
    let progress: Double
    let percentText: String

    var body: some View {
        VStack(spacing: 14) {
            Text("Загрузка фото…")
                .font(.headline)

            ProgressView(value: progress)
                .frame(maxWidth: 260)

            Text(percentText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(radius: 18)
    }
}

private struct PortfolioGrid: View {
    let images: [PortfolioImage]
    let onTap: (Int) -> Void
    let onLongPressDelete: (PortfolioImage) -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(Array(images.enumerated()), id: \.element.id) { idx, img in
                ZStack {
                    CachedAsyncImage(
                        url: img.imageUrl,
                        targetSize: CGSize(width: 140, height: 140),
                        contentMode: .fill,
                        showsProgress: true,
                        failureIcon: "exclamationmark.triangle"
                    )
                }
                .frame(height: 110)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .contentShape(Rectangle())
                .onTapGesture {
                    onTap(idx)
                }
                .contextMenu {
                    Button(role: .destructive) {
                        onLongPressDelete(img)
                    } label: {
                        Label("Удалить", systemImage: "trash")
                    }
                }
            }
        }
    }
}
