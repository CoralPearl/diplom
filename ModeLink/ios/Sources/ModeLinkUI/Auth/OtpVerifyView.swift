import SwiftUI
import UIKit

@MainActor
final class OtpVerifyViewModel: ObservableObject {
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    func verify(email: String, code: String, password: String, role: Role, adminSecret: String?, appState: AppState) async -> Bool {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }

        do {
            let body = OtpVerifyBody(email: email, code: code, password: password, role: role, adminRegistrationSecret: adminSecret)
            let resp: AuthTokenResponse = try await APIClient.shared.post("/auth/otp/verify", body: body, requiresAuth: false)
            appState.setSession(token: resp.token, user: resp.user)
            return true
        } catch {
            self.errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            return false
        }
    }
}

struct OtpVerifyView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @StateObject private var vm = OtpVerifyViewModel()

    let email: String

    @State private var code: String = ""
    @State private var password: String = ""
    @State private var role: Role = .model
    @State private var adminSecret: String = ""
    @State private var didAttemptSubmit: Bool = false

    private var codeErrorToShow: String? {
        let trimmed = Validators.trimmed(code)
        let shouldShow = didAttemptSubmit || !trimmed.isEmpty
        guard shouldShow else { return nil }
        return Validators.otpCodeError(trimmed)
    }

    private var passwordErrorToShow: String? {
        let shouldShow = didAttemptSubmit || !password.isEmpty
        guard shouldShow else { return nil }
        return Validators.passwordStrengthError(password)
    }

    var body: some View {
        Form {
            Section {
                Text(email)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Email")
            }

            Section("Подтверждение") {
                VStack(alignment: .leading, spacing: 6) {
                    TextField("6-значный код", text: $code.filtered { InputFilters.digits($0, maxLength: 6) })
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)

                    if let err = codeErrorToShow {
                        InlineErrorText(message: err)
                    } else {
                        InlineHintText(message: "Введи 6 цифр из письма.")
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    SecureField("Пароль", text: $password)
                        .textContentType(.newPassword)

                    if let err = passwordErrorToShow {
                        InlineErrorText(message: err)
                    } else {
                        InlineHintText(message: "Минимум 8 символов, 1 заглавная, 1 строчная, 1 цифра.")
                    }
                }
            }

            Section("Роль") {
                Picker("Роль", selection: $role) {
                    ForEach(Role.allCases) { r in
                        Text(r.titleRu).tag(r)
                    }
                }

                if role == .admin {
                    TextField("Admin secret (если требуется)", text: $adminSecret)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)

                    InlineHintText(message: "Если admin-регистрация отключена или защищена секретом — backend вернёт ошибку.")
                }
            }

            if let error = vm.errorMessage {
                Section {
                    ErrorBox(message: error)
                }
            }

            Section {
                Button {
                    didAttemptSubmit = true

                    guard codeErrorToShow == nil else { return }
                    guard passwordErrorToShow == nil else { return }

                    Task {
                        let ok = await vm.verify(
                            email: email,
                            code: Validators.trimmed(code),
                            password: password,
                            role: role,
                            adminSecret: adminSecret.isEmpty ? nil : adminSecret,
                            appState: appState
                        )
                        if ok {
                            dismiss()
                        }
                    }
                } label: {
                    HStack {
                        if vm.isLoading { ProgressView() }
                        Text("Завершить регистрацию")
                    }
                }
                .disabled(vm.isLoading)
            }
        }
        .navigationTitle("Введите код")
        .keyboardDoneToolbar()
    }
}
