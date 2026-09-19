import XCTest

class ExceptionsTests: XCTestCase {
    private func entry(_ bundleId: String, hide: ExceptionHidePreference = .always, ignore: ExceptionIgnorePreference = .none, title: String? = nil) -> ExceptionEntry {
        ExceptionEntry(bundleIdentifier: bundleId, hide: hide, ignore: ignore, windowTitleContains: title)
    }

    func testDisplayNameForResolvedApp() {
        XCTAssertEqual(ExceptionsTestable.displayName(bundleIdentifier: "com.apple.finder", resolvedName: "Finder"), "Finder")
    }

    func testDisplayNameForPrefixEntry() {
        XCTAssertTrue(ExceptionsTestable.isPrefix("com.parallels."))
        XCTAssertEqual(ExceptionsTestable.displayName(bundleIdentifier: "com.parallels.", resolvedName: nil),
            "All apps starting with \"com.parallels.\"")
    }

    func testDisplayNameForUnresolvedApp() {
        XCTAssertFalse(ExceptionsTestable.isPrefix("com.example.missing"))
        XCTAssertEqual(ExceptionsTestable.displayName(bundleIdentifier: "com.example.missing", resolvedName: nil), "com.example.missing")
    }

    func testInsertAppendsNewEntry() {
        let result = ExceptionsTestable.insert([entry("com.apple.finder")], bundleIdentifier: "com.apple.Safari")
        XCTAssertEqual(result?.map { $0.bundleIdentifier }, ["com.apple.finder", "com.apple.Safari"])
    }

    func testInsertTrimsWhitespace() {
        let result = ExceptionsTestable.insert([], bundleIdentifier: "  com.apple.Safari  ")
        XCTAssertEqual(result?.first?.bundleIdentifier, "com.apple.Safari")
    }

    func testInsertRejectsDuplicate() {
        XCTAssertNil(ExceptionsTestable.insert([entry("com.apple.finder")], bundleIdentifier: "com.apple.finder"))
    }

    func testInsertRejectsEmpty() {
        XCTAssertNil(ExceptionsTestable.insert([], bundleIdentifier: "   "))
    }

    func testUpdateChangesOnlyPassedFields() {
        let entries = [entry("com.apple.finder", hide: .always, ignore: .none)]
        let updated = ExceptionsTestable.update(entries, at: 0, hide: .windowTitleContains)
        XCTAssertEqual(updated[0].hide, .windowTitleContains)
        XCTAssertEqual(updated[0].ignore, ExceptionIgnorePreference.none)
    }

    func testUpdateOutOfBoundsIsNoOp() {
        let entries = [entry("com.apple.finder")]
        XCTAssertEqual(ExceptionsTestable.update(entries, at: 5, hide: .always).count, 1)
    }

    func testRemoveDeletesEntryAtIndex() {
        let entries = [entry("com.apple.finder"), entry("com.apple.Safari")]
        XCTAssertEqual(ExceptionsTestable.remove(entries, at: 0).map { $0.bundleIdentifier }, ["com.apple.Safari"])
    }

    func testRemoveOutOfBoundsIsNoOp() {
        let entries = [entry("com.apple.finder")]
        XCTAssertEqual(ExceptionsTestable.remove(entries, at: 5).count, 1)
    }
}
