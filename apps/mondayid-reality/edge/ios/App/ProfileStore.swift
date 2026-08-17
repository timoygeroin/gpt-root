import Foundation
import SwiftUI

@MainActor
final class ProfileStore: ObservableObject {
    @Published var home: String { didSet { persist() } }
    @Published var work: String { didSet { persist() } }
    @Published var family: String { didSet { persist() } }
    @Published var route: String { didSet { persist() } }
    @Published var hasCompletedSetup: Bool { didSet { persist() } }

    private let defaults: UserDefaults
    private var isLoading = true

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let visualAudit = ProcessInfo.processInfo.environment["MONDAYID_VISUAL_AUDIT"] == "1"
        self.home = defaults.string(forKey: "reality.profile.home") ?? (visualAudit ? "Nahariya" : "")
        self.work = defaults.string(forKey: "reality.profile.work") ?? (visualAudit ? "Haifa" : "")
        self.family = defaults.string(forKey: "reality.profile.family") ?? (visualAudit ? "Nahariya" : "")
        self.route = defaults.string(forKey: "reality.profile.route") ?? (visualAudit ? "Nahariya, Haifa" : "")
        self.hasCompletedSetup = defaults.bool(forKey: "reality.profile.setup") || visualAudit
        self.isLoading = false
    }

    var profile: PersonalProfile {
        PersonalProfile(homeAreas: parse(home), workAreas: parse(work), familyAreas: parse(family), routeAreas: parse(route))
    }

    var contexts: [(String, String)] {
        [("Home", home), ("Work", work), ("Family", family), ("Route", route)]
            .filter { !$0.1.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    var hasAnyArea: Bool { !profile.allAreas.isEmpty }

    func completeSetup() { hasCompletedSetup = true }

    private func parse(_ raw: String) -> Set<String> {
        Set(raw.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty })
    }

    private func persist() {
        guard !isLoading else { return }
        defaults.set(home, forKey: "reality.profile.home")
        defaults.set(work, forKey: "reality.profile.work")
        defaults.set(family, forKey: "reality.profile.family")
        defaults.set(route, forKey: "reality.profile.route")
        defaults.set(hasCompletedSetup, forKey: "reality.profile.setup")
    }
}
