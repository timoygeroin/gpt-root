import Foundation

public enum AuthorityState: String, Codable {
    case officialActive = "OFFICIAL_ACTIVE"
    case officialObservedNoActiveItems = "OFFICIAL_NO_ACTIVE_ITEMS_OBSERVED"
    case coverageIncomplete = "COVERAGE_INCOMPLETE"
}

public struct PersonalProfile: Codable {
    public var homeAreas: Set<String>
    public var workAreas: Set<String>
    public var familyAreas: Set<String>
    public var routeAreas: Set<String>

    public init(homeAreas: Set<String>, workAreas: Set<String>, familyAreas: Set<String>, routeAreas: Set<String>) {
        self.homeAreas = homeAreas
        self.workAreas = workAreas
        self.familyAreas = familyAreas
        self.routeAreas = routeAreas
    }

    public var allAreas: Set<String> { homeAreas.union(workAreas).union(familyAreas).union(routeAreas) }
}

public struct LocalReality: Codable {
    public let state: AuthorityState
    public let relevantAlerts: [OrefAlert]
    public let affectedContexts: [String]
    public let action: String
    public let reason: String
}

public enum RealityFusion {
    public static func derive(official: OrefObservation, profile: PersonalProfile) -> LocalReality {
        guard official.coverage == .reachable else {
            return LocalReality(state: .coverageIncomplete, relevantAlerts: [], affectedContexts: [],
                                action: "KEEP_OFFICIAL_ALERTS_ENABLED",
                                reason: "Official receptor coverage is incomplete; absence of data is not safety.")
        }

        let normalizedProfile = Set(profile.allAreas.map(normalize))
        let relevant = official.alerts.filter { alert in
            !Set(alert.areas.map(normalize)).isDisjoint(with: normalizedProfile)
        }

        if relevant.isEmpty {
            return LocalReality(state: .officialObservedNoActiveItems, relevantAlerts: [], affectedContexts: [],
                                action: "NONE_FROM_RUNTIME",
                                reason: "No active official item was observed for saved contexts in this poll. This is not a declaration that the person is safe.")
        }

        var contexts = Set<String>()
        for alert in relevant {
            let a = Set(alert.areas.map(normalize))
            if !a.isDisjoint(with: Set(profile.homeAreas.map(normalize))) { contexts.insert("HOME") }
            if !a.isDisjoint(with: Set(profile.workAreas.map(normalize))) { contexts.insert("WORK") }
            if !a.isDisjoint(with: Set(profile.familyAreas.map(normalize))) { contexts.insert("FAMILY") }
            if !a.isDisjoint(with: Set(profile.routeAreas.map(normalize))) { contexts.insert("ROUTE") }
        }

        return LocalReality(state: .officialActive, relevantAlerts: relevant, affectedContexts: contexts.sorted(),
                            action: "FOLLOW_CURRENT_OFFICIAL_INSTRUCTIONS",
                            reason: "An official-origin active item intersects a saved personal context.")
    }

    private static func normalize(_ s: String) -> String {
        s.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
