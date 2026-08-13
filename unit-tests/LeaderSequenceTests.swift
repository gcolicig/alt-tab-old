import XCTest

final class LeaderSequenceTests: XCTestCase {
    private let w = LeaderKey(keyCode: 13)
    private let s = LeaderKey(keyCode: 1)
    private let l = LeaderKey(keyCode: 37)
    private let r = LeaderKey(keyCode: 15)

    private func trie() -> LeaderTrie {
        // w -> l/r as window layouts, s as a direct binding at the root
        LeaderTrie([
            w: .group([
                l: .action(.windowLayout(.leftThird)),
                r: .action(.windowLayout(.rightThird)),
            ]),
            s: .action(.space(.left)),
        ])
    }

    func testASingleKeyBindingRunsImmediately() {
        XCTAssertEqual(trie().lookup([s]), .run(.space(.left)))
    }

    func testAPrefixReportsWhatMayFollow() {
        guard case .awaitMore(let next) = trie().lookup([w]) else { return XCTFail("expected a prefix") }
        XCTAssertEqual(Set(next), [l, r])
    }

    func testANestedSequenceRunsOnItsLastKey() {
        XCTAssertEqual(trie().lookup([w, l]), .run(.windowLayout(.leftThird)))
        XCTAssertEqual(trie().lookup([w, r]), .run(.windowLayout(.rightThird)))
    }

    func testAnUnknownKeyDoesNotMatch() {
        XCTAssertEqual(trie().lookup([r]), .noMatch)
        XCTAssertEqual(trie().lookup([w, s]), .noMatch)
    }

    /// Keys beyond a finished binding are not part of it, so they must not silently extend the match.
    func testKeysBeyondACompleteBindingDoNotMatch() {
        XCTAssertEqual(trie().lookup([s, l]), .noMatch)
    }

    func testTheEmptySequenceOffersTheRootKeys() {
        guard case .awaitMore(let next) = trie().lookup([]) else { return XCTFail("expected the root") }
        XCTAssertEqual(Set(next), [w, s])
    }

    /// With nothing bound there is nothing to await. Reporting `awaitMore` with an empty list would have a
    /// caller arm a session that can only swallow the next key and then abort — the outcome the type exists
    /// to avoid, and reachable simply by not configuring any bindings.
    func testAnEmptyTrieOffersNothingRatherThanAnEmptyWait() {
        XCTAssertEqual(LeaderTrie().lookup([]), .noMatch)
    }

    func testAPrefixLeadingToAnEmptyGroupOffersNothing() {
        let trie = LeaderTrie([w: .group([:])])
        XCTAssertEqual(trie.lookup([w]), .noMatch)
    }

    func testASessionOnAnEmptyTrieAbortsOnTheFirstKey() {
        XCTAssertEqual(LeaderSession.accept(LeaderSession.begin(), key: s, in: LeaderTrie()), .abort)
    }

    func testASessionWalksAPrefixAndThenRuns() {
        let started = LeaderSession.begin()
        guard case .keepCollecting(let afterW) = LeaderSession.accept(started, key: w, in: trie()) else {
            return XCTFail("expected to keep collecting")
        }
        XCTAssertEqual(afterW, [w])
        XCTAssertEqual(LeaderSession.accept(.collecting(afterW), key: l, in: trie()), .run(.windowLayout(.leftThird)))
    }

    func testEscapeAborts() {
        let escape = LeaderKey(keyCode: LeaderSession.abortKeyCode)
        XCTAssertEqual(LeaderSession.accept(.collecting([]), key: escape, in: trie()), .abort)
        XCTAssertEqual(LeaderSession.accept(.collecting([w]), key: escape, in: trie()), .abort)
    }

    /// Swallowing a keystroke that means nothing here is worse than making the user start over.
    func testAWrongKeyAbortsInsteadOfBeingIgnored() {
        XCTAssertEqual(LeaderSession.accept(.collecting([w]), key: s, in: trie()), .abort)
    }

    func testAnIdleSessionAcceptsNothing() {
        XCTAssertEqual(LeaderSession.accept(.idle, key: w, in: trie()), .abort)
    }

    func testTheSequenceExpires() {
        XCTAssertFalse(LeaderSession.hasExpired(lastKeyAt: 100, now: 101))
        XCTAssertTrue(LeaderSession.hasExpired(lastKeyAt: 100, now: 100 + LeaderSession.timeout))
    }

    /// Caps Lock and the numeric pad flag ride along on ordinary keystrokes and must not change a binding.
    func testOnlyDistinguishingModifiersAreKept() {
        XCTAssertEqual(LeaderKey(keyCode: 13, modifiers: [.command, .capsLock]), LeaderKey(keyCode: 13, modifiers: [.command]))
        XCTAssertNotEqual(LeaderKey(keyCode: 13, modifiers: [.command]), LeaderKey(keyCode: 13, modifiers: [.control]))
    }
}
