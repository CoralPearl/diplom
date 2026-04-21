import SwiftUI

@MainActor
final class OtpRequestViewModel: ObservableObject {
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    @Published var expiresAt: Date? = nil

    func request(email: String) async -> Bool {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }

        do {
            let body = OtpRequestBody(email: email)
            let resp: OtpRequestResponse = try await APIClient.shared.post("/auth/otp/request", body: body, requiresAuth: false)
            self.expiresAt = resp.expiresAt
            return true
        } catch {
            self.errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            return false
        }
    }
}

struct OtpRequestView: View {
    @StateObject private var vm = OtpRequestViewModel()

    @State private var email: String = ""
    @State private var didAttemptSubmit: Bool = false
    @State private var goVerify: Bool = false

    private var trimmedEmail: String { Validators.trimmed(email) }

    private var emailErrorToShow: String? {
        let shouldShow = didAttemptSubmit || !trimmedEmail.isEmpty
        guard shouldShow else { return nil }
        return Validators.emailError(trimmedEmail)
    }

    var body: some View {
        VStack(spacing: 12) {
            Text("Регистрация через код на email")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 6) {
                TextField("Email", text: $email)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .autocorrectionDisabled(true)
                    .textFieldStyle(.roundedBorder)

                if let err = emailErrorToShow {
                    InlineErrorText(message: err)
                } else {
                    InlineHintText(message: "Мы отправим 6-значный код подтверждения на этот email.")
                }
            }

            if let error = vm.errorMessage {
                ErrorBox(message: error)
            }

            Button {
                didAttemptSubmit = true

                guard emailErrorToShow == nil else { return }

                Task {
                    let ok = await vm.request(email: trimmedEmail)
                    if ok {
                        goVerify = true
                    }
                }
            } label: {
                HStack {
                    if vm.isLoading { ProgressView() }
                    Text("Отправить код")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(vm.isLoading)

            if let expiresAt = vm.expiresAt {
                Text("Код действителен до: \(expiresAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            NavigationLink(isActive: $goVerify) {
                OtpVerifyView(email: trimmedEmail)
            } label: {
                EmptyView()
            }
            .hidden()
        }
    }
}
