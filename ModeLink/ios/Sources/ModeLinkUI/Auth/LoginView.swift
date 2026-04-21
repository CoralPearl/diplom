import SwiftUI

@MainActor
final class LoginViewModel: ObservableObject {
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    func login(email: String, password: String, appState: AppState) async -> Bool {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }

        do {
            let body = LoginBody(email: email, password: password)
            let resp: AuthTokenResponse = try await APIClient.shared.post("/auth/login", body: body, requiresAuth: false)
            appState.setSession(token: resp.token, user: resp.user)
            return true
        } catch {
            self.errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            return false
        }
    }
}

struct LoginView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var vm = LoginViewModel()

    @State private var email: String = ""
    @State private var password: String = ""
    @State private var didAttemptSubmit: Bool = false

    private var trimmedEmail: String { Validators.trimmed(email) }

    private var emailErrorToShow: String? {
        let shouldShow = didAttemptSubmit || !trimmedEmail.isEmpty
        guard shouldShow else { return nil }
        return Validators.emailError(trimmedEmail)
    }

    private var passwordErrorToShow: String? {
        let shouldShow = didAttemptSubmit
        guard shouldShow else { return nil }
        return password.isEmpty ? "Пароль обязателен" : nil
    }

    var body: some View {
        VStack(spacing: 12) {
            Text("Вход по email + пароль")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 6) {
                TextField("Email", text: $email)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .textContentType(.username)
                    .autocorrectionDisabled(true)
                    .textFieldStyle(.roundedBorder)

                if let err = emailErrorToShow {
                    InlineErrorText(message: err)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                SecureField("Пароль", text: $password)
                    .textContentType(.password)
                    .textFieldStyle(.roundedBorder)

                if let err = passwordErrorToShow {
                    InlineErrorText(message: err)
                }
            }

            if let error = vm.errorMessage {
                ErrorBox(message: error)
            }

            Button {
                didAttemptSubmit = true

                guard emailErrorToShow == nil else { return }
                guard passwordErrorToShow == nil else { return }

                Task {
                    _ = await vm.login(
                        email: trimmedEmail,
                        password: password,
                        appState: appState
                    )
                }
            } label: {
                HStack {
                    if vm.isLoading { ProgressView() }
                    Text("Войти")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(vm.isLoading)
        }
    }
}
