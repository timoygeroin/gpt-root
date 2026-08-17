import SwiftUI

struct ProfileEditorView: View {
    @ObservedObject var profile: ProfileStore
    @ObservedObject var registry: ZoneRegistry
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    contextLink("Home", selection: $profile.homeIDs)
                    contextLink("Work", selection: $profile.workIDs)
                    contextLink("Family", selection: $profile.familyIDs)
                    contextLink("Route", selection: $profile.routeIDs)
                } header: {
                    Text("Your reality")
                } footer: {
                    Text("Choose Home Front Command alert zones. The saved zone identities stay on this device and are used only to determine whether an observed official-origin item intersects your reality.")
                }

                if let failure = registry.loadFailure {
                    Section("Zone registry") {
                        LabeledContent("State", value: failure)
                        Text("A broken or incomplete registry cannot silently become a personal relevance decision.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
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
                    .disabled(!profile.hasAnyArea || registry.loadFailure != nil)
                }
            }
        }
        .interactiveDismissDisabled(!profile.hasCompletedSetup || !profile.hasAnyArea)
    }

    private func contextLink(_ title: LocalizedStringKey, selection: Binding<Set<Int>>) -> some View {
        NavigationLink {
            ZoneSelectionView(title: title, selection: selection, registry: registry)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.body.weight(.semibold))
                Text(registry.displaySummary(for: selection.wrappedValue))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .padding(.vertical, 3)
        }
    }
}

private struct ZoneSelectionView: View {
    let title: LocalizedStringKey
    @Binding var selection: Set<Int>
    @ObservedObject var registry: ZoneRegistry
    @State private var query = ""

    private var results: [AlertZone] { registry.search(query) }

    var body: some View {
        List(results) { zone in
            Button {
                if selection.contains(zone.id) { selection.remove(zone.id) }
                else { selection.insert(zone.id) }
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(zone.displayName())
                            .foregroundStyle(.primary)
                        HStack(spacing: 8) {
                            if !zone.zoneName().isEmpty { Text(zone.zoneName()) }
                            Text("\(zone.countdown)s")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if selection.contains(zone.id) {
                        Image(systemName: "checkmark")
                            .font(.body.weight(.semibold))
                            .accessibilityLabel("Selected")
                    }
                }
            }
            .buttonStyle(.plain)
        }
        .searchable(text: $query, prompt: "Search alert zones")
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if registry.loadFailure != nil {
                ContentUnavailableView("Zone registry unavailable", systemImage: "exclamationmark.triangle")
            }
        }
    }
}
