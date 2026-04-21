import SwiftUI

struct AdminUserDetailView: View {
    @Environment(\.dismiss) private var dismiss

    let user: AdminUser
    let currentAdminId: UUID?
    let onUpdated: (AdminUser) -> Void

    @State private var role: Role
    @State private var isBlocked: Bool

    @State private var isSaving: Bool = false
    @State private var errorMessage: String? = nil

    init(user: AdminUser, currentAdminId: UUID?, onUpdated: @escaping (AdminUser) -> Void) {
        self.user = user
        self.currentAdminId = currentAdminId
        self.onUpdated = onUpdated
        _role = State(initialValue: user.role)
        _isBlocked = State(initialValue: user.isBlocked)
    }

    var body: some View {
        Form {
            Section("Аккаунт") {
                LabeledContent("Email", value: user.email)
                LabeledContent("Создан", value: dateString(user.createdAt))
                LabeledContent("Верификация", value: user.isVerified ? "Да" : "Нет")
            }

            Section("Права") {
                Picker("Роль", selection: $role) {
                    ForEach(Role.allCases) { r in
                        Text(r.titleRu).tag(r)
                    }
                }

                Toggle("Заблокирован", isOn: $isBlocked)
                    .disabled(isMe)
                    .tint(.red)

                if isMe {
                    Text("Нельзя заблокировать самого себя.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            if let err = errorMessage {
                Section {
                    Text(err)
                        .foregroundStyle(.red)
                }
            }

            Section {
                Button {
                    Task { await save() }
                } label: {
                    if isSaving {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    } else {
                        Text("Сохранить")
                            .frame(maxWidth: .infinity)
                    }
                }
                .disabled(isSaving || !hasChanges)
            }
        }
        .navigationTitle("Пользователь")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var isMe: Bool {
        guard let me = currentAdminId else { return false }
        return me == user.id
    }

    private var hasChanges: Bool {
        role != user.role || isBlocked != user.isBlocked
    }

    private func dateString(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: date)
    }

    private func save() async {
        errorMessage = nil
        isSaving = true
        defer { isSaving = false }

        let roleValue: Role? = (role == user.role) ? nil : role
        let blockedValue: Bool? = (isBlocked == user.isBlocked) ? nil : isBlocked

        guard roleValue != nil || blockedValue != nil else {
            dismiss()
            return
        }

        do {
            let updated: AdminUser = try await APIClient.shared.patch(
                "/admin/users/\(user.id.uuidString)",
                body: AdminUpdateUserRequest(role: roleValue, isBlocked: blockedValue)
            )
            onUpdated(updated)
            dismiss()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}
