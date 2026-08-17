import Foundation

public enum CoverageState: String, Codable, Sendable {
    case reachable = "REACHABLE"
    case geoBlocked = "GEO_BLOCKED"
    case degraded = "DEGRADED"
    case offline = "OFFLINE"
    case unknown = "UNKNOWN"
}

public struct OrefAlert: Codable, Hashable, Sendable {
    public let sourceEventId: String
    public let category: String
    public let title: String
    public let areas: [String]
    public let instruction: String

    public init(sourceEventId: String, category: String, title: String, areas: [String], instruction: String) {
        self.sourceEventId = sourceEventId
        self.category = category
        self.title = title
        self.areas = areas
        self.instruction = instruction
    }
}

public struct OrefObservation: Codable, Sendable {
    public let observedAt: Date
    public let coverage: CoverageState
    public let httpStatus: Int?
    public let alerts: [OrefAlert]
    public let invariant: String

    public init(observedAt: Date, coverage: CoverageState, httpStatus: Int?, alerts: [OrefAlert], invariant: String) {
        self.observedAt = observedAt
        self.coverage = coverage
        self.httpStatus = httpStatus
        self.alerts = alerts
        self.invariant = invariant
    }
}

public actor OrefReceptor {
    private let session: URLSession
    private let endpoint = URL(string: "https://www.oref.org.il/warningMessages/alert/Alerts.json")!

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func observe() async -> OrefObservation {
        var request = URLRequest(url: endpoint)
        request.timeoutInterval = 4
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.setValue("https://www.oref.org.il/", forHTTPHeaderField: "Referer")
        request.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Mozilla/5.0 MONDAYID-Reality-iOS/0.9", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await session.data(for: request)
            let http = response as? HTTPURLResponse
            let status = http?.statusCode
            guard let status else { return observation(.unknown, nil, []) }
            guard (200..<300).contains(status) else {
                return observation(status == 403 ? .geoBlocked : .degraded, status, [])
            }
            let clean = sanitize(data)
            guard !clean.isEmpty else { return observation(.reachable, status, []) }

            struct Wire: Decodable {
                let id: StringOrInt?
                let cat: StringOrInt?
                let title: String?
                let data: [String]?
                let desc: String?
            }

            guard let wire = try? JSONDecoder().decode(Wire.self, from: clean) else {
                return observation(.degraded, status, [])
            }
            guard let areas = wire.data, !areas.isEmpty else { return observation(.reachable, status, []) }

            let alert = OrefAlert(sourceEventId: wire.id?.stringValue ?? "", category: wire.cat?.stringValue ?? "UNKNOWN", title: wire.title ?? "Alert", areas: areas, instruction: wire.desc ?? "")
            return observation(.reachable, status, [alert])
        } catch {
            return observation(.offline, nil, [])
        }
    }

    private func observation(_ state: CoverageState, _ status: Int?, _ alerts: [OrefAlert]) -> OrefObservation {
        OrefObservation(observedAt: Date(), coverage: state, httpStatus: status, alerts: alerts,
                        invariant: "An empty or failed receptor response is never a declaration of safety.")
    }

    private func sanitize(_ data: Data) -> Data {
        var bytes = Array(data)
        if bytes.starts(with: [0xEF, 0xBB, 0xBF]) { bytes.removeFirst(3) }
        bytes.removeAll(where: { $0 == 0 })
        return Data(bytes)
    }
}

private enum StringOrInt: Decodable {
    case string(String)
    case int(Int)
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let s = try? c.decode(String.self) { self = .string(s); return }
        self = .int(try c.decode(Int.self))
    }
    var stringValue: String {
        switch self { case .string(let s): return s; case .int(let i): return String(i) }
    }
}
