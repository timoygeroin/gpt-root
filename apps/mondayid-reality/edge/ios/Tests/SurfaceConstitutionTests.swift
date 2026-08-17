import XCTest

final class SurfaceConstitutionTests: XCTestCase {
    private var appSource: String {
        get throws {
            let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            let app = root.appendingPathComponent("edge/ios/App")
            let files = try FileManager.default.contentsOfDirectory(at: app, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "swift" }
            return try files.map { try String(contentsOf: $0, encoding: .utf8) }.joined(separator: "\n")
        }
    }

    func testNoHardCodedRGBInUserSurface() throws {
        let source = try appSource
        XCTAssertFalse(source.contains("Color(red:"), "Use semantic/system colors; fixed RGB makes appearance and accessibility brittle.")
        XCTAssertFalse(source.contains("UIColor(red:"), "Use semantic/system colors; fixed RGB makes appearance and accessibility brittle.")
    }

    func testNoCustomGestureLanguageForStandardActions() throws {
        let source = try appSource
        ["DragGesture(", "MagnificationGesture(", "RotationGesture(", ".onTapGesture", ".gesture("].forEach {
            XCTAssertFalse(source.contains($0), "Standard navigation/actions must remain standard controls and gestures.")
        }
    }

    func testNoUnsafePersonalConditionClaim() throws {
        let source = try appSource.lowercased()
        let forbidden = ["you are safe", "you're safe", "all safe", "person is safe", "person's safety"]
        forbidden.forEach { phrase in
            XCTAssertFalse(source.contains(phrase), "The surface must not infer a person's physical condition from alert transport state.")
        }
    }

    func testNoTinyFixedTypographyInUserSurface() throws {
        let source = try appSource
        let regex = try NSRegularExpression(pattern: #"\.font\(\.system\(size:\s*([0-9]+(?:\.[0-9]+)?)"#)
        let range = NSRange(source.startIndex..., in: source)
        for match in regex.matches(in: source, range: range) {
            guard let sizeRange = Range(match.range(at: 1), in: source), let size = Double(source[sizeRange]) else { continue }
            XCTAssertGreaterThanOrEqual(size, 11, "Fixed text below 11pt is forbidden; prefer Dynamic Type styles.")
        }
    }

    func testMainSurfaceDoesNotRegressIntoDashboard() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let content = try String(contentsOf: root.appendingPathComponent("edge/ios/App/ContentView.swift"), encoding: .utf8)
        XCTAssertFalse(content.contains("Grid("))
        XCTAssertFalse(content.contains("LazyVGrid("))
        XCTAssertFalse(content.contains("TabView("), "The primary safety state must not become a tabbed dashboard.")
    }
}
