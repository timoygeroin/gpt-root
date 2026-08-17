import Foundation
import SwiftUI

@MainActor
final class RealityViewModel: ObservableObject {
    @Published var tick: EdgeRuntime.Tick?
    @Published var isRefreshing = false

    private let runtime = EdgeRuntime()
    private var refreshTask: Task<Void, Never>?

    let profile = PersonalProfile(
        homeAreas: ["Nahariya"],
        workAreas: ["Haifa"],
        familyAreas: ["Nahariya"],
        routeAreas: ["Nahariya", "Haifa"]
    )

    var headline: String {
        guard let tick else { return "Reading reality…" }
        switch tick.reality.state {
        case .officialActive: return "Your reality changed."
        case .coverageIncomplete: return "Coverage incomplete."
        case .officialObservedNoActiveItems: return "No relevant active item observed."
        }
    }

    var accent: Color {
        guard let tick else { return .secondary }
        switch tick.reality.state {
        case .officialActive: return .red
        case .coverageIncomplete: return .orange
        case .officialObservedNoActiveItems: return .secondary
        }
    }

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
    }
}
