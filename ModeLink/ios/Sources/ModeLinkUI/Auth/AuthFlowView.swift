import SwiftUI

struct AuthFlowView: View {
    enum Mode: String, CaseIterable, Identifiable {
        case register = "Регистрация"
        case login = "Вход"
        var id: String { rawValue }
    }

    @State private var mode: Mode = .register

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Picker("", selection: $mode) {
                    ForEach(Mode.allCases) { m in
                        Text(m.rawValue).tag(m)
                    }
                }
                .pickerStyle(.segmented)

                if mode == .register {
                    OtpRequestView()
                } else {
                    LoginView()
                }

                Spacer(minLength: 0)
            }
            .padding()
            .navigationTitle("ModeLink")
        }
    }
}
