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

class LaunchAppTargetTests: XCTestCase {
    func testNameSpellingsThatMeanTheSameApplication() {
        XCTAssertTrue(LaunchAppTarget.matches("TextEdit", applicationName: "TextEdit"))
        XCTAssertTrue(LaunchAppTarget.matches("textedit", applicationName: "TextEdit"))
        XCTAssertTrue(LaunchAppTarget.matches("  TextEdit.app ", applicationName: "TextEdit"))
        XCTAssertTrue(LaunchAppTarget.matches("Microsoft Word", applicationName: "Microsoft Word"))
    }

    func testDifferentApplicationsDoNotMatch() {
        XCTAssertFalse(LaunchAppTarget.matches("TextEdit", applicationName: "TextMate"))
        XCTAssertFalse(LaunchAppTarget.matches("", applicationName: "TextEdit"))
        XCTAssertFalse(LaunchAppTarget.matches("   ", applicationName: "TextEdit"))
    }

    func testBundleIdentifierIsOnlyTriedForValuesThatCouldBeOne() {
        XCTAssertTrue(LaunchAppTarget.couldBeBundleIdentifier("com.apple.TextEdit"))
        XCTAssertFalse(LaunchAppTarget.couldBeBundleIdentifier("TextEdit"))
        XCTAssertFalse(LaunchAppTarget.couldBeBundleIdentifier("Microsoft Word"))
        XCTAssertFalse(LaunchAppTarget.couldBeBundleIdentifier(""))
    }

    func testAnAppNamedLikeABundleIdStillFallsThroughToTheNameLookup() {
        // draw.io looks like a bundle identifier, so the lookup must not stop when no such bundle exists
        XCTAssertTrue(LaunchAppTarget.couldBeBundleIdentifier("draw.io"))
        XCTAssertTrue(LaunchAppTarget.matches("draw.io", applicationName: "draw.io"))
    }
}
