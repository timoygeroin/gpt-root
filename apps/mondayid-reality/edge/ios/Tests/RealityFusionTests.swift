import XCTest
@testable import MondayIDRealityEdge

final class RealityFusionTests: XCTestCase {
    let profile = PersonalProfile(homeAreas: ["Nahariya"], workAreas: ["Haifa"], familyAreas: [], routeAreas: ["Nahariya", "Haifa"])

    func testCoverageFailureNeverBecomesSafety() {
        let o = OrefObservation(observedAt: Date(), coverage: .offline, httpStatus: nil, alerts: [], invariant: "test")
        let r = RealityFusion.derive(official: o, profile: profile)
        XCTAssertEqual(r.state, .coverageIncomplete)
        XCTAssertEqual(r.action, "KEEP_OFFICIAL_ALERTS_ENABLED")
    }

    func testRelevantOfficialAlertTouchesPersonalContext() {
        let alert = OrefAlert(sourceEventId: "1", category: "1", title: "Alert", areas: ["Nahariya"], instruction: "Official instruction")
        let o = OrefObservation(observedAt: Date(), coverage: .reachable, httpStatus: 200, alerts: [alert], invariant: "test")
        let r = RealityFusion.derive(official: o, profile: profile)
        XCTAssertEqual(r.state, .officialActive)
        XCTAssertTrue(r.affectedContexts.contains("HOME"))
        XCTAssertTrue(r.affectedContexts.contains("ROUTE"))
    }

    func testEmptyReachableObservationIsNotNamedSafe() {
        let o = OrefObservation(observedAt: Date(), coverage: .reachable, httpStatus: 200, alerts: [], invariant: "test")
        let r = RealityFusion.derive(official: o, profile: profile)
        XCTAssertEqual(r.state, .officialObservedNoActiveItems)
        XCTAssertFalse(r.reason.lowercased().contains("safe"))
    }

    func testActiveStateIsRetainedAcrossCoverageGapUntilAuthoritativelyCleared() async {
        let alert = OrefAlert(sourceEventId: "A", category: "1", title: "Alert", areas: ["Nahariya"], instruction: "Official instruction")
        let sequence = ObservationSequence([
            OrefObservation(observedAt: Date(), coverage: .reachable, httpStatus: 200, alerts: [alert], invariant: "test"),
            OrefObservation(observedAt: Date(), coverage: .offline, httpStatus: nil, alerts: [], invariant: "test"),
            OrefObservation(observedAt: Date(), coverage: .reachable, httpStatus: 200, alerts: [], invariant: "test")
        ])
        let runtime = EdgeRuntime(observeOfficial: { await sequence.next() })

        let active = await runtime.tick(profile: profile)
        XCTAssertEqual(active.reality.state, .officialActive)
        XCTAssertEqual(active.lifecycle, "NEW")

        let gap = await runtime.tick(profile: profile)
        XCTAssertEqual(gap.reality.state, .retainedActiveDuringCoverageGap)
        XCTAssertEqual(gap.lifecycle, "COVERAGE_GAP_RETAINED_ACTIVE")
        XCTAssertEqual(gap.reality.relevantAlerts.first?.sourceEventId, "A")

        let cleared = await runtime.tick(profile: profile)
        XCTAssertEqual(cleared.reality.state, .officialObservedNoActiveItems)
        XCTAssertEqual(cleared.lifecycle, "RESOLVED_FROM_VIEW")
    }
}

private actor ObservationSequence {
    private var values: [OrefObservation]
    init(_ values: [OrefObservation]) { self.values = values }
    func next() -> OrefObservation {
        if values.isEmpty { return OrefObservation(observedAt: Date(), coverage: .offline, httpStatus: nil, alerts: [], invariant: "exhausted") }
        return values.removeFirst()
    }
}
