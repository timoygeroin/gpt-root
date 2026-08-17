import Foundation

public actor EdgeRuntime {
    private let observeOfficial: @Sendable () async -> OrefObservation
    private var lastRelevantIDs: Set<String> = []
    private var lastConfirmedActive: LocalReality?

    public init(receptor: OrefReceptor = OrefReceptor()) {
        self.observeOfficial = { await receptor.observe() }
    }

    init(observeOfficial: @escaping @Sendable () async -> OrefObservation) {
        self.observeOfficial = observeOfficial
    }

    public struct Tick: Codable, Sendable {
        public let official: OrefObservation
        public let reality: LocalReality
        public let lifecycle: String
    }

    public func tick(profile: PersonalProfile) async -> Tick {
        let official = await observeOfficial()
        let observed = RealityFusion.derive(official: official, profile: profile)

        if observed.state == .officialActive {
            lastConfirmedActive = observed
        }

        if observed.state == .coverageIncomplete, let prior = lastConfirmedActive {
            return Tick(official: official, reality: RealityFusion.retainActive(prior), lifecycle: "COVERAGE_GAP_RETAINED_ACTIVE")
        }

        let now = Set(observed.relevantAlerts.map(\.sourceEventId))
        let lifecycle: String
        if lastRelevantIDs.isEmpty && !now.isEmpty {
            lifecycle = "NEW"
        } else if !lastRelevantIDs.isEmpty && now.isEmpty {
            lifecycle = "RESOLVED_FROM_VIEW"
        } else if now == lastRelevantIDs {
            lifecycle = now.isEmpty ? "UNCHANGED" : "PERSISTING"
        } else {
            lifecycle = "CHANGED"
        }

        if official.coverage == .reachable {
            lastRelevantIDs = now
            if observed.state == .officialObservedNoActiveItems { lastConfirmedActive = nil }
        }

        return Tick(official: official, reality: observed, lifecycle: lifecycle)
    }
}
