import Foundation
import SwiftUI

@MainActor
final class ProfileStore: ObservableObject {
    @Published var homeIDs: Set<Int> { didSet { persist() } }
    @Published var workIDs: Set<Int> { didSet { persist() } }
    @Published var familyIDs: Set<Int> { didSet { persist() } }
    @Published var routeIDs: Set<Int> { didSet { persist() } }
    @Published var hasCompletedSetup: Bool { didSet { persist() } }

    private let defaults: UserDefaults
    private var isLoading = true

    init(registry: ZoneRegistry, defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let visualAudit = ProcessInfo.processInfo.environment["MONDAYID_VISUAL_AUDIT"] == "1"
        homeIDs = Self.readSet(defaults, key: "reality.profile.homeIDs")
        workIDs = Self.readSet(defaults, key: "reality.profile.workIDs")
        familyIDs = Self.readSet(defaults, key: "reality.profile.familyIDs")
        routeIDs = Self.readSet(defaults, key: "reality.profile.routeIDs")
        hasCompletedSetup = defaults.bool(forKey: "reality.profile.setup")

        if visualAudit && homeIDs.isEmpty && workIDs.isEmpty {
            let nahariya = Set(registry.search("Nahariya").prefix(1).map(\.id))
            let haifa = Set(registry.search("Haifa").prefix(2).map(\.id))
            homeIDs = nahariya
            familyIDs = nahariya
            workIDs = haifa
            routeIDs = nahariya.union(haifa)
            hasCompletedSetup = !homeIDs.isEmpty || !workIDs.isEmpty
        }
        isLoading = false
    }

    func profile(using registry: ZoneRegistry) -> PersonalProfile {
        PersonalProfile(
            homeAreas: registry.officialAreaValues(for: homeIDs),
            workAreas: registry.officialAreaValues(for: workIDs),
            familyAreas: registry.officialAreaValues(for: familyIDs),
            routeAreas: registry.officialAreaValues(for: routeIDs)
        )
    }

    func contexts(using registry: ZoneRegistry) -> [(String, String)] {
        [
            (String(localized: "Home"), registry.displaySummary(for: homeIDs)),
            (String(localized: "Work"), registry.displaySummary(for: workIDs)),
            (String(localized: "Family"), registry.displaySummary(for: familyIDs)),
            (String(localized: "Route"), registry.displaySummary(for: routeIDs))
        ].filter { !$0.1.isEmpty && $0.1 != String(localized: "Not set") }
    }

    var hasAnyArea: Bool { !homeIDs.isEmpty || !workIDs.isEmpty || !familyIDs.isEmpty || !routeIDs.isEmpty }

    func completeSetup() { hasCompletedSetup = true }

    private static func readSet(_ defaults: UserDefaults, key: String) -> Set<Int> {
        guard let values = defaults.array(forKey: key) as? [Int] else { return [] }
        return Set(values)
    }

    private func persist() {
        guard !isLoading else { return }
        defaults.set(Array(homeIDs).sorted(), forKey: "reality.profile.homeIDs")
        defaults.set(Array(workIDs).sorted(), forKey: "reality.profile.workIDs")
        defaults.set(Array(familyIDs).sorted(), forKey: "reality.profile.familyIDs")
        defaults.set(Array(routeIDs).sorted(), forKey: "reality.profile.routeIDs")
        defaults.set(hasCompletedSetup, forKey: "reality.profile.setup")
    }
}
