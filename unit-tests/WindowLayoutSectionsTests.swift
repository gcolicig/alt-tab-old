import XCTest

final class WindowLayoutSectionsTests: XCTestCase {
    func testEveryActionAppearsExactlyOnce() {
        let grouped = WindowLayoutSections.grouped()
        let flattened = grouped.flatMap { $0.1 }
        XCTAssertEqual(flattened.count, WindowLayoutAction.allCases.count)
        WindowLayoutAction.allCases.forEach { action in
            XCTAssertEqual(flattened.filter { $0 == action }.count, 1)
        }
    }

    func testRestoreIsFoldedIntoFocus() {
        XCTAssertEqual(WindowLayoutSections.section(.restore), .focus)
    }

    func testNoSectionIsEmpty() {
        WindowLayoutSections.grouped().forEach { _, actions in
            XCTAssertFalse(actions.isEmpty)
        }
    }
}
