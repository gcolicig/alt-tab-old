import XCTest

private struct FakeNode: AccessibilityNode {
    var role: String?
    var subrole: String? = nil
    var roleDescription: String? = nil
    var title: String? = nil
    var identifier: String? = nil
    var frame: CGRect? = nil
    var isEnabled: Bool? = nil
    var isFocused: Bool? = nil
    var settableAttributes: [String] = []
    var children: [AccessibilityNode] = []
}

class DebugToolsTests: XCTestCase {
    func testUserContentPreferencesAreRedacted() {
        XCTAssertEqual(DebugRedaction.preferenceValue(key: "openUrlValue3", value: "https://bank.example"), "<set>")
        XCTAssertEqual(DebugRedaction.preferenceValue(key: "openUrlValue0", value: ""), "<empty>")
        XCTAssertEqual(DebugRedaction.preferenceValue(key: "exceptions", value: "[{\"a\":1},{\"b\":2}]"), "<2 entries>")
        XCTAssertEqual(DebugRedaction.preferenceValue(key: "leaderEnabled", value: "true"), "true")
        XCTAssertEqual(DebugRedaction.preferenceValue(key: "x", value: nil), "nil")
    }

    func testHomeDirectoryBecomesTilde() {
        XCTAssertEqual(DebugRedaction.homeRedacted("/Users/jane/Apps/X.app", home: "/Users/jane"), "~/Apps/X.app")
        XCTAssertEqual(DebugRedaction.homeRedacted("/tmp", home: "/"), "/tmp")
    }

    func testTitlesOfContentAreReducedToTheirLength() {
        XCTAssertEqual(AccessibilityTreeFormat.displayTitle("Salary 2026.xlsx", role: "AXWindow"), "<title 16 chars>")
        XCTAssertEqual(AccessibilityTreeFormat.displayTitle("Save", role: "AXButton"), "Save")
        XCTAssertEqual(AccessibilityTreeFormat.displayTitle(String(repeating: "a", count: 70), role: "AXButton").count, 61)
    }

    func testSecureFieldsShowOnlyTheirRole() {
        let node = FakeNode(role: "AXSecureTextField", title: "hunter2", identifier: "pw", isFocused: true)
        XCTAssertEqual(AccessibilityTreeFormat.line(node), "AXSecureTextField")
    }

    func testTreeIsIndentedAndShowsSettableAttributes() {
        let child = FakeNode(role: "AXButton", title: "OK", isEnabled: false)
        let root = FakeNode(role: "AXWindow", subrole: "AXStandardWindow", frame: CGRect(x: 1, y: 2, width: 3, height: 4),
            settableAttributes: ["Position", "Size"], children: [child])
        XCTAssertEqual(AccessibilityTreeFormat.render(root), "AXWindow (AXStandardWindow) frame=(1,2 3x4) settable=Position,Size\n  AXButton title=OK disabled")
    }

    func testDeepTreesAreTruncated() {
        var node = FakeNode(role: "AXGroup")
        (0..<12).forEach { _ in node = FakeNode(role: "AXGroup", children: [node]) }
        let output = AccessibilityTreeFormat.render(node)
        XCTAssertEqual(output.split(separator: "\n").count, AccessibilityTreeFormat.maxDepth + 1)
        XCTAssertTrue(output.hasSuffix("elements"))
    }

    func testPermissionResetTouchesOnlyTheOwnBundle() {
        XCTAssertEqual(PermissionResetCommand.arguments(bundleId: "com.example.app"),
                       [["reset", "Accessibility", "com.example.app"], ["reset", "ScreenCapture", "com.example.app"]])
    }
}
