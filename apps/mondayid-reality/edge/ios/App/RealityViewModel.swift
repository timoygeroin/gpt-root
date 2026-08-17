import Foundation
import SwiftUI

@MainActor
final class RealityViewModel: ObservableObject {
    @Published private(set) var tick: EdgeRuntime.Tick?
    @Published private(set) var isRefreshing = false
    @Published private(set) var lastObservedAt: Date?

    private let runtime = EdgeRuntime()
    private var refreshTask: Task<Void, Never>?
    private var profile = PersonalProfile(homeAreas: [], workAreas: [], familyAreas: [], routeAreas: [])

    var phase: RealitySurfacePhase {
        guard let tick else { return .loading }
        if tick.lifecycle == "RESOLVED_FROM_VIEW" { return .resolved }
        switch tick.reality.state {
        case .officialActive: return .active
        case .coverageIncomplete: return .coverageIncomplete
        case .officialObservedNoActiveItems: return .unchanged
        }
    }

    var headline: String {
        switch phase {
        case .loading: return String(localized: "Reading reality")
        case .unchanged: return String(localized: "No relevant change observed")
        case .coverageIncomplete: return String(localized: "Coverage incomplete")
        case .active: return String(localized: "Your reality changed")
        case .resolved: return String(localized: "Relevant item no longer observed")
        }
    }

    var explanation: String {
        guard tick != nil else { return String(localized: "Checking the official-origin foreground receptor.") }
        switch phase {
        case .loading:
            return String(localized: "Checking the official-origin foreground receptor.")
        case .unchanged:
            return String(localized: "No active official item was observed for your saved contexts in this foreground check.")
        case .coverageIncomplete:
            return String(localized: "The foreground official-origin check is incomplete. No conclusion is derived from missing coverage.")
        case .active:
            return String(localized: "An official-origin active item intersects a saved personal context.")
        case .resolved:
            return String(localized: "The previously relevant item is no longer present in the current foreground observation.")
        }
    }

    var affectedContexts: [String] { tick?.reality.affectedContexts ?? [] }
    var relevantAlerts: [OrefAlert] { tick?.reality.relevantAlerts ?? [] }

    func setProfile(_ newProfile: PersonalProfile) { profile = newProfile }

    func start() {
        guard refreshTask == nil else { return }
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh()
                try? await Task.sleep(for: .seconds(5))
            }
        }
    }

    func stop() {
        refreshTask?.cancel()
        refreshTask = nil
    }

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        tick = await runtime.tick(profile: profile)
        lastObservedAt = Date()
    }
}
