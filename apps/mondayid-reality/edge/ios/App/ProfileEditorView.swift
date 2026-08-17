import SwiftUI

struct ProfileEditorView: View {
    @ObservedObject var profile: ProfileStore
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: Field?

    enum Field: Hashable { case home, work, family, route }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    contextField("Home", text: $profile.home, field: .home, prompt: "e.g. Nahariya")
                    contextField("Work", text: $profile.work, field: .work, prompt: "e.g. Haifa")
                    contextField("Family", text: $profile.family, field: .family, prompt: "e.g. Nahariya")
                    contextField("Route", text: $profile.route, field: .route, prompt: "e.g. Nahariya, Haifa")
                } header: {
                    Text("Your reality")
                } footer: {
                    Text("Saved contexts stay on this device in this prototype. Separate multiple areas with commas. The app uses them only to decide whether an observed item intersects your reality.")
                }

                Section("Background authority") {
                    LabeledContent("Official alerts", value: "Independent")
                    Text("iOS does not guarantee continuous background polling. Keep the current Home Front Command alert channel enabled. MONDAYID REALITY verifies and personalizes official-origin observations while active; it does not replace the authority channel.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(profile.hasCompletedSetup ? "Contexts" : "Set your contexts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        profile.completeSetup()
                        dismiss()
                    }
                    .disabled(!profile.hasAnyArea)
                }
            }
        }
        .interactiveDismissDisabled(!profile.hasCompletedSetup || !profile.hasAnyArea)
    }

    @ViewBuilder
    private func contextField(_ title: String, text: Binding<String>, field: Field, prompt: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            TextField(prompt, text: text)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled(false)
                .focused($focusedField, equals: field)
                .submitLabel(field == .route ? .done : .next)
                .onSubmit { advance(from: field) }
        }
        .padding(.vertical, 2)
    }

    private func advance(from field: Field) {
        switch field {
        case .home: focusedField = .work
        case .work: focusedField = .family
        case .family: focusedField = .route
        case .route: focusedField = nil
        }
    }
}
