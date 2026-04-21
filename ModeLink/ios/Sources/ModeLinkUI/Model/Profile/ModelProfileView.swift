import SwiftUI
import UIKit

struct ModelProfileView: View {
    @StateObject private var vm = ModelProfileViewModel()
    @StateObject private var queue = OfflineActionQueue.shared
    @StateObject private var network = NetworkMonitor.shared

    var body: some View {
        NavigationStack {
            Form {
                if let action = queue.profileAction() {
                    Section("Синхронизация") {
                        switch action.status {
                        case .pending:
                            HStack(spacing: 12) {
                                ProgressView()
                                Text(network.isConnected ? "Изменения ждут отправки…" : "Оффлайн: отправим изменения при появлении сети")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }

                        case .failed:
                            VStack(alignment: .leading, spacing: 8) {
                                ErrorBox(message: action.lastError ?? "Не удалось синхронизировать изменения")

                                HStack {
                                    Button {
                                        OfflineActionQueue.shared.markPending(id: action.id)
                                        OfflineSyncEngine.shared.kick()
                                    } label: {
                                        Label("Повторить", systemImage: "arrow.clockwise")
                                    }

                                    Spacer()

                                    Button(role: .destructive) {
                                        OfflineActionQueue.shared.remove(id: action.id)
                                    } label: {
                                        Label("Убрать", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                }

                Section("Основное") {
                    ValidatedFormRow(
                        title: "ФИО",
                        text: $vm.fullName,
                        keyboardType: .default,
                        autocapitalization: .words,
                        error: vm.didAttemptSave ? vm.fullNameError : nil,
                        hint: nil,
                        filter: nil
                    )
                }

                Section("Параметры") {
                    ValidatedFormRow(
                        title: "Рост (см)",
                        text: $vm.height,
                        keyboardType: .numberPad,
                        error: vm.heightError,
                        hint: "Диапазон: 120–220",
                        filter: { InputFilters.digits($0, maxLength: 3) }
                    )

                    ValidatedFormRow(
                        title: "Вес (кг)",
                        text: $vm.weight,
                        keyboardType: .numberPad,
                        error: vm.weightError,
                        hint: "Диапазон: 30–200",
                        filter: { InputFilters.digits($0, maxLength: 3) }
                    )

                    ValidatedFormRow(
                        title: "Грудь (см)",
                        text: $vm.bust,
                        keyboardType: .numberPad,
                        error: vm.bustError,
                        hint: "Диапазон: 50–160",
                        filter: { InputFilters.digits($0, maxLength: 3) }
                    )

                    ValidatedFormRow(
                        title: "Талия (см)",
                        text: $vm.waist,
                        keyboardType: .numberPad,
                        error: vm.waistError,
                        hint: "Диапазон: 40–140",
                        filter: { InputFilters.digits($0, maxLength: 3) }
                    )

                    ValidatedFormRow(
                        title: "Бёдра (см)",
                        text: $vm.hips,
                        keyboardType: .numberPad,
                        error: vm.hipsError,
                        hint: "Диапазон: 60–170",
                        filter: { InputFilters.digits($0, maxLength: 3) }
                    )

                    ValidatedFormRow(
                        title: "Размер обуви (EU)",
                        text: $vm.shoeSize,
                        keyboardType: .decimalPad,
                        error: vm.shoeSizeError,
                        hint: "Диапазон: 30–50 (можно 37.5)",
                        filter: { InputFilters.decimal($0, maxIntegerDigits: 2, maxFractionDigits: 1) }
                    )
                } footer: {
                    InlineHintText(message: "Все параметры кроме ФИО — необязательные. Если вводишь значение, оно должно быть в допустимом диапазоне.")
                }

                if let error = vm.errorMessage {
                    Section {
                        ErrorBox(message: error)
                    }
                }

                if let success = vm.successMessage {
                    Section {
                        Label(success, systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }

                Section {
                    Button {
                        Task { await vm.save() }
                    } label: {
                        HStack {
                            if vm.isSaving { ProgressView() }
                            Text("Сохранить")
                        }
                    }
                    .disabled(vm.isSaving)
                }
            }
            .navigationTitle("Профиль")
            .keyboardDoneToolbar()
            .overlay {
                if vm.isLoading {
                    LoadingView(title: "", subtitle: "Загрузка профиля…")
                        .background(.ultraThinMaterial)
                }
            }
            .task {
                await vm.load()
            }
            .refreshable {
                await vm.load()
            }
        }
    }
}

private struct ValidatedFormRow: View {
    let title: String
    @Binding var text: String

    var keyboardType: UIKeyboardType = .default
    var autocapitalization: TextInputAutocapitalization = .never
    var error: String? = nil
    var hint: String? = nil
    var filter: ((String) -> String)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let filter {
                TextField(title, text: $text.filtered(filter))
                    .keyboardType(keyboardType)
                    .textInputAutocapitalization(autocapitalization)
            } else {
                TextField(title, text: $text)
                    .keyboardType(keyboardType)
                    .textInputAutocapitalization(autocapitalization)
            }

            if let error {
                InlineErrorText(message: error)
            } else if let hint {
                InlineHintText(message: hint)
            }
        }
        .padding(.vertical, 2)
    }
}
