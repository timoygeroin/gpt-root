import Foundation

public actor EdgeRuntime {
    private let receptor: OrefReceptor
    private var lastRelevantIDs: Set<String> = []

    public init(receptor: OrefReceptor = OrefReceptor()) {
        self.receptor = receptor
    }

    public struct Tick: Codable {
        public let official: OrefObservation
        public let reality: LocalReality
        public let lifecycle: String
    }

    public func tick(profile: PersonalProfile) async -> Tick {
        let official = await receptor.observe()
        let reality = RealityFusion.derive(official: official, profile: profile)
        let now = Set(reality.relevantAlerts.map(\.sourceEventId))
        let lifecycle: String
        if lastRelevantIDs.isEmpty && !now.isEmpty { lifecycle = "NEW" }
        else if !lastRelevantIDs.isEmpty && now.isEmpty { lifecycle = "RESOLVED_FROM_VIEW" }
        else if now == lastRelevantIDs { lifecycle = now.isEmpty ? "UNCHANGED" : "PERSISTING" }
        else { lifecycle = "CHANGED" }
        lastRelevantIDs = now
        return Tick(official: official, reality: reality, lifecycle: lifecycle)
    }
}
