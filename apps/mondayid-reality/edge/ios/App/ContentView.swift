import SwiftUI

struct ContentView: View {
    @StateObject private var model = RealityViewModel()
    @StateObject private var profile = ProfileStore()
    @State private var showContexts = false
    @State private var showDetails = false

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityContrast) private var accessibilityContrast
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var palette: SurfacePalette {
        SurfacePalette.palette(for: model.phase, contrast: accessibilityContrast)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                palette.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        statusHeader
                        Spacer(minLength: 54)
                        stateSurface
                        Spacer(minLength: 48)
                        receipt
                    }
                    .frame(maxWidth: 620, minHeight: 660, alignment: .topLeading)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 18)
                    .frame(maxWidth: .infinity)
                }
                .refreshable { await model.refresh() }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Contexts") { showContexts = true }
                        .buttonStyle(PressFeedbackStyle())
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .sheet(isPresented: $showContexts) { ProfileEditorView(profile: profile) }
        .sheet(isPresented: $showDetails) { DetailsView(model: model, profile: profile) }
        .task {
            syncProfile()
            if !profile.hasCompletedSetup || !profile.hasAnyArea { showContexts = true }
            if scenePhase == .active && profile.hasAnyArea { model.start() }
        }
        .onChange(of: scenePhase) { _, newValue in
            if newValue == .active && profile.hasAnyArea {
                syncProfile()
                model.start()
            } else {
                model.stop()
            }
        }
        .onChange(of: profile.home) { _, _ in syncProfile() }
        .onChange(of: profile.work) { _, _ in syncProfile() }
        .onChange(of: profile.family) { _, _ in syncProfile() }
        .onChange(of: profile.route) { _, _ in syncProfile() }
        .onChange(of: profile.hasCompletedSetup) { _, completed in
            syncProfile()
            if completed && profile.hasAnyArea && scenePhase == .active { model.start() }
        }
        .animation(reduceMotion ? nil : .smooth(duration: 0.28), value: model.phase)
    }

    private var statusHeader: some View {
        HStack(spacing: 10) {
            Text("MONDAYID REALITY")
                .font(.caption.weight(.semibold))
                .tracking(1.1)
                .foregroundStyle(.secondary)
            Spacer()
            StateGlyph(phase: model.phase)
                .foregroundStyle(palette.accent)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("MondayID Reality, \(model.headline)")
    }

    private var stateSurface: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(model.headline)
                .font(.largeTitle.weight(.semibold))
                .foregroundStyle(palette.primary)
                .contentTransition(.interpolate)
                .accessibilityAddTraits(.isHeader)

            Text(model.explanation)
                .font(.body)
                .foregroundStyle(palette.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if model.phase == .active {
                activeInstruction.transition(.opacity.combined(with: .move(edge: .top)))
            } else if model.phase == .coverageIncomplete {
                coverageNotice.transition(.opacity)
            } else if model.phase == .resolved {
                resolvedNotice.transition(.opacity)
            }
        }
    }

    private var activeInstruction: some View {
        VStack(alignment: .leading, spacing: 18) {
            Divider()
            Label("Official-origin active item", systemImage: "exclamationmark.octagon.fill")
                .font(.headline)
                .foregroundStyle(.red)

            if !model.affectedContexts.isEmpty {
                Text(model.affectedContexts.joined(separator: " · "))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            ForEach(model.relevantAlerts, id: \.sourceEventId) { alert in
                VStack(alignment: .leading, spacing: 8) {
                    if !alert.title.isEmpty {
                        Text(alert.title).font(.title3.weight(.semibold))
                    }
                    if !alert.instruction.isEmpty {
                        Text(alert.instruction)
                            .font(.title2.weight(.semibold))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .accessibilityElement(children: .combine)
            }

            Text("Follow the current official Home Front Command instruction. This app adds personal relevance; it does not replace the official alert channel.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Divider()
        }
        .padding(.vertical, 12)
        .accessibilityElement(children: .contain)
    }

    private var coverageNotice: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Foreground verification unavailable", systemImage: "exclamationmark.triangle")
                .font(.headline)
                .foregroundStyle(.primary)
            Text("Keep the independent official alert channel enabled. Missing transport is treated as missing knowledge, never as an all-clear signal.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 18)
        .accessibilityElement(children: .combine)
    }

    private var resolvedNotice: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Changed since the previous observation").font(.headline)
            Text("A previously relevant active item is no longer present in the current foreground observation. Continue to follow current official instructions.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 18)
    }

    private var receipt: some View {
        VStack(alignment: .leading, spacing: 14) {
            Divider()
            HStack(alignment: .firstTextBaseline) {
                if let lastObservedAt = model.lastObservedAt {
                    Text("Observed \(lastObservedAt, style: .relative) ago")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Foreground observation not yet completed")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Details") { showDetails = true }
                    .font(.footnote.weight(.semibold))
                    .buttonStyle(PressFeedbackStyle())
            }
        }
    }

    private func syncProfile() { model.setProfile(profile.profile) }
}

private struct DetailsView: View {
    @ObservedObject var model: RealityViewModel
    @ObservedObject var profile: ProfileStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Observation") {
                    LabeledContent("Surface phase", value: phaseLabel)
                    if let tick = model.tick {
                        LabeledContent("Authority state", value: tick.reality.state.rawValue)
                        LabeledContent("Lifecycle", value: tick.lifecycle)
                        LabeledContent("Foreground transport", value: tick.official.coverage.rawValue)
                    }
                }
                Section("Saved contexts") {
                    ForEach(Array(profile.contexts.enumerated()), id: \.offset) { _, context in
                        LabeledContent(context.0, value: context.1)
                    }
                }
                Section("System contract") {
                    Text("The foreground local receptor may verify official-origin observations and compute personal relevance. iOS does not guarantee continuous background polling, so the independent official alert channel remains the authority path when this app is suspended.")
                    Text("Missing data never becomes a personal-condition claim. Cloud context and secondary sources cannot override an official-origin active state.")
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
            .navigationTitle("Reality receipt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }

    private var phaseLabel: String {
        switch model.phase {
        case .loading: return "LOADING"
        case .unchanged: return "UNCHANGED"
        case .coverageIncomplete: return "COVERAGE_INCOMPLETE"
        case .active: return "ACTIVE"
        case .resolved: return "RESOLVED_FROM_VIEW"
        }
    }
}
