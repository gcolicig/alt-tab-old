import XCTest

class OpenUrlTargetTests: XCTestCase {
    func testAHostWithoutASchemeBecomesHttps() {
        XCTAssertEqual(OpenUrlTarget.normalized("github.com")?.absoluteString, "https://github.com")
        XCTAssertEqual(OpenUrlTarget.normalized("www.example.co.uk/path")?.absoluteString,
                       "https://www.example.co.uk/path")
    }

    func testAnExistingSchemeIsKeptAsWritten() {
        XCTAssertEqual(OpenUrlTarget.normalized("http://example.com")?.absoluteString, "http://example.com")
        XCTAssertEqual(OpenUrlTarget.normalized("https://example.com")?.absoluteString, "https://example.com")
        XCTAssertEqual(OpenUrlTarget.normalized("mailto:someone@example.com")?.absoluteString,
                       "mailto:someone@example.com")
        XCTAssertEqual(OpenUrlTarget.normalized("raycast://confetti")?.absoluteString, "raycast://confetti")
    }

    func testSurroundingWhitespaceIsIgnored() {
        XCTAssertEqual(OpenUrlTarget.normalized("  github.com \n")?.absoluteString, "https://github.com")
    }

    func testEmptyOrBlankInputHasNoTarget() {
        XCTAssertNil(OpenUrlTarget.normalized(""))
        XCTAssertNil(OpenUrlTarget.normalized("   "))
    }

    func testPlainWordsDoNotSilentlyBecomeWebAddresses() {
        XCTAssertNil(OpenUrlTarget.normalized("github"))
        XCTAssertNil(OpenUrlTarget.normalized("some note to self"))
        // a trailing or leading dot is not a host either
        XCTAssertNil(OpenUrlTarget.normalized("github."))
        XCTAssertNil(OpenUrlTarget.normalized(".com"))
    }
}
