import SwiftUI

struct ProjectEditorView: View {
    enum Mode {
        case create
        case edit(Project)

        var title: String {
            switch self {
            case .create: return "Новый проект"
            case .edit: return "Редактировать"
            }
        }
    }

    @Environment(\.dismiss) private var dismiss

    let mode: Mode
    /// Return `nil` on success, or a user-friendly error message.
    let onSubmit: (String, Date, String) async -> String?

    @State private var title: String
    @State private var date: Date
    @State private var location: String

    @State private var isSaving: Bool = false
    @State private var didAttemptSave: Bool = false

    /// Backend/network errors after submit.
    @State private var errorMessage: String? = nil

    init(mode: Mode, onSubmit: @escaping (String, Date, String) async -> String?) {
        self.mode = mode
        self.onSubmit = onSubmit

        switch mode {
        case .create:
            _title = State(initialValue: "")
            _date = State(initialValue: Date())
            _location = State(initialValue: "")
        case .edit(let project):
            _title = State(initialValue: project.title)
            _date = State(initialValue: project.date)
            _location = State(initialValue: project.location)
        }
    }

    private var trimmedTitle: String { Validators.trimmed(title) }
    private var trimmedLocation: String { Validators.trimmed(location) }

    private var titleErrorToShow: String? {
        let shouldShow = didAttemptSave || !trimmedTitle.isEmpty
        guard shouldShow else { return nil }
        return Validators.lengthError(title, fieldName: "Название", min: 2, max: 80)
    }

    private var locationErrorToShow: String? {
        let shouldShow = didAttemptSave || !trimmedLocation.isEmpty
        guard shouldShow else { return nil }
        return Validators.lengthError(location, fieldName: "Локация", min: 2, max: 80)
    }

    private var dateRange: ClosedRange<Date> {
        // Prevent obviously wrong dates while still allowing past projects.
        let cal = Calendar(identifier: .gregorian)
        let min = cal.date(from: DateComponents(year: 2000, month: 1, day: 1)) ?? .distantPast
        let max = cal.date(from: DateComponents(year: 2100, month: 12, day: 31)) ?? .distantFuture
        return min...max
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        TextField("Название", text: $title)

                        if let err = titleErrorToShow {
                            InlineErrorText(message: err)
                        }
                    }

                    DatePicker("Дата", selection: $date, in: dateRange)

                    VStack(alignment: .leading, spacing: 6) {
                        TextField("Локация", text: $location)

                        if let err = locationErrorToShow {
                            InlineErrorText(message: err)
                        }
                    }
                } footer: {
                    InlineHintText(message: "Название и локация — обязательные. Дата ограничена диапазоном 2000–2100.")
                }

                if let errorMessage {
                    Section {
                        ErrorBox(message: errorMessage)
                    }
                }
            }
            .navigationTitle(mode.title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await save() }
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Сохранить")
                        }
                    }
                    .disabled(isSaving)
                }
            }
        }
    }

    private func save() async {
        errorMessage = nil
        didAttemptSave = true

        // Local validation
        guard titleErrorToShow == nil else { return }
        guard locationErrorToShow == nil else { return }
        guard dateRange.contains(date) else {
            errorMessage = "Дата вне допустимого диапазона"
            return
        }

        isSaving = true
        defer { isSaving = false }

        let err = await onSubmit(trimmedTitle, date, trimmedLocation)

        if err == nil {
            dismiss()
        } else {
            errorMessage = err
        }
    }
}
