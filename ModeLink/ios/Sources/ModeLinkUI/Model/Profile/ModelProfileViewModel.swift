import Foundation

@MainActor
final class ModelProfileViewModel: ObservableObject {
    @Published var isLoading: Bool = false
    @Published var isSaving: Bool = false

    /// Backend/network errors.
    @Published var errorMessage: String? = nil

    @Published var successMessage: String? = nil

    /// Used to show required-field errors only after user tries to save.
    @Published var didAttemptSave: Bool = false

    // Form fields (String for convenient masked input)
    @Published var fullName: String = ""
    @Published var height: String = ""
    @Published var weight: String = ""
    @Published var bust: String = ""
    @Published var waist: String = ""
    @Published var hips: String = ""
    @Published var shoeSize: String = ""

    // MARK: - Validation ranges (can be adjusted)

    private enum Ranges {
        static let heightCm: ClosedRange<Int> = 120...220
        static let weightKg: ClosedRange<Int> = 30...200
        static let bustCm: ClosedRange<Int> = 50...160
        static let waistCm: ClosedRange<Int> = 40...140
        static let hipsCm: ClosedRange<Int> = 60...170
        static let shoeEU: ClosedRange<Double> = 30.0...50.0
    }

    // MARK: - Computed validation errors

    var fullNameError: String? {
        Validators.requiredTextError(fullName, fieldName: "ФИО")
    }

    var heightError: String? {
        Validators.intOptionalError(height, fieldName: "Рост (см)", range: Ranges.heightCm)
    }

    var weightError: String? {
        Validators.intOptionalError(weight, fieldName: "Вес (кг)", range: Ranges.weightKg)
    }

    var bustError: String? {
        Validators.intOptionalError(bust, fieldName: "Грудь (см)", range: Ranges.bustCm)
    }

    var waistError: String? {
        Validators.intOptionalError(waist, fieldName: "Талия (см)", range: Ranges.waistCm)
    }

    var hipsError: String? {
        Validators.intOptionalError(hips, fieldName: "Бёдра (см)", range: Ranges.hipsCm)
    }

    var shoeSizeError: String? {
        Validators.doubleOptionalError(shoeSize, fieldName: "Размер обуви (EU)", range: Ranges.shoeEU)
    }

    var firstValidationError: String? {
        [
            fullNameError,
            heightError,
            weightError,
            bustError,
            waistError,
            hipsError,
            shoeSizeError
        ]
        .compactMap { $0 }
        .first
    }

    // MARK: - Parsing helpers

    private func parseInt(_ s: String) -> Int? {
        let t = Validators.trimmed(s)
        guard !t.isEmpty else { return nil }
        return Int(t)
    }

    private func parseDouble(_ s: String) -> Double? {
        let t = Validators.trimmed(s)
        guard !t.isEmpty else { return nil }
        let normalized = t.replacingOccurrences(of: ",", with: ".")
        return Double(normalized)
    }

    // MARK: - API

    func load() async {
        errorMessage = nil
        successMessage = nil
        didAttemptSave = false

        isLoading = true
        defer { isLoading = false }

        do {
            let profile: ModelProfile = try await APIClient.shared.get("/model-profile/me")

            fullName = profile.fullName
            height = profile.height.map(String.init) ?? ""
            weight = profile.weight.map(String.init) ?? ""
            bust = profile.bust.map(String.init) ?? ""
            waist = profile.waist.map(String.init) ?? ""
            hips = profile.hips.map(String.init) ?? ""
            shoeSize = profile.shoeSize.map { String($0) } ?? ""

            // If there is a pending offline update, apply it on top of server data.
            applyPendingOfflineProfileIfAny()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription

            // Even if load failed (offline), we may still have local pending changes.
            applyPendingOfflineProfileIfAny()
        }
    }

    private func applyPendingOfflineProfileIfAny() {
        guard let action = OfflineActionQueue.shared.profileAction() else { return }
        guard case .modelProfile(let update) = action.payload else { return }

        // Apply latest local values (so user sees what will be synced).
        if let name = update.fullName {
            fullName = name
        }
        height = update.height.map(String.init) ?? ""
        weight = update.weight.map(String.init) ?? ""
        bust = update.bust.map(String.init) ?? ""
        waist = update.waist.map(String.init) ?? ""
        hips = update.hips.map(String.init) ?? ""
        shoeSize = update.shoeSize.map { String($0) } ?? ""

        if action.status == .pending {
            successMessage = "Есть несинхронизированные изменения"
        }
        if action.status == .failed {
            errorMessage = action.lastError ?? "Не удалось синхронизировать изменения"
        }
    }

    func save() async {
        // Validation
        didAttemptSave = true
        successMessage = nil
        errorMessage = nil

        if firstValidationError != nil {
            // Inline errors are shown in UI. We keep errorMessage empty to avoid duplicates.
            return
        }

        isSaving = true
        defer { isSaving = false }

        do {
            let body = ModelProfileUpdate(
                fullName: Validators.trimmed(fullName),
                height: parseInt(height),
                weight: parseInt(weight),
                bust: parseInt(bust),
                waist: parseInt(waist),
                hips: parseInt(hips),
                shoeSize: parseDouble(shoeSize)
            )

            let _: ModelProfile = try await APIClient.shared.put("/model-profile", body: body)
            successMessage = "Сохранено"
        } catch {
            if let apiErr = error as? APIError, (apiErr.isOfflineLike || apiErr.isTransient) {
                // Queue for later sync.
                _ = OfflineActionQueue.shared.enqueueProfileUpdate(
                    ModelProfileUpdate(
                        fullName: Validators.trimmed(fullName),
                        height: parseInt(height),
                        weight: parseInt(weight),
                        bust: parseInt(bust),
                        waist: parseInt(waist),
                        hips: parseInt(hips),
                        shoeSize: parseDouble(shoeSize)
                    )
                )
                OfflineSyncEngine.shared.kick()
                successMessage = "Сохранено локально — синхронизация при появлении сети"
                errorMessage = nil
            } else {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        }
    }
}
