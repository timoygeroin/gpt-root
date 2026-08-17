import XCTest
@testable import MondayIDRealityEdge

final class RealityFusionTests: XCTestCase {
    let profile = PersonalProfile(
        homeAreas: ["Nahariya"],
        workAreas: ["Haifa"],
        familyAreas: [],
        routeAreas: ["Nahariya", "Haifa"]
    )

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
}
