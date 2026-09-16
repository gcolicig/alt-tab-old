import XCTest

final class SpaceIdentityTests: XCTestCase {
    private let spaces = [
        SpaceIdentityEntry(uuid: "aaaa", index: 1),
        SpaceIdentityEntry(uuid: "bbbb", index: 2),
        SpaceIdentityEntry(uuid: nil, index: 3), // a fullscreen space with no stable UUID
    ]

    func testAUuidResolvesToItsCurrentIndex() {
        XCTAssertEqual(SpaceIdentity.index(forUuid: "aaaa", in: spaces), 1)
        XCTAssertEqual(SpaceIdentity.index(forUuid: "bbbb", in: spaces), 2)
    }

    /// A binding to a space that is gone resolves to nil — never to another space.
    func testAMissingUuidResolvesToNilInsteadOfGuessing() {
        XCTAssertNil(SpaceIdentity.index(forUuid: "cccc", in: spaces))
        XCTAssertFalse(SpaceIdentity.isPresent("cccc", in: spaces))
        XCTAssertTrue(SpaceIdentity.isPresent("aaaa", in: spaces))
    }

    /// The index shifts when spaces are reordered, but the UUID follows the space.
    func testResolutionFollowsTheUuidWhenIndexesShift() {
        let reordered = [
            SpaceIdentityEntry(uuid: "bbbb", index: 1),
            SpaceIdentityEntry(uuid: "aaaa", index: 2),
        ]
        XCTAssertEqual(SpaceIdentity.index(forUuid: "aaaa", in: reordered), 2)
        XCTAssertEqual(SpaceIdentity.index(forUuid: "bbbb", in: reordered), 1)
    }

    func testIndexToUuidRoundTrips() {
        XCTAssertEqual(SpaceIdentity.uuid(forIndex: 2, in: spaces), "bbbb")
        // a space without a UUID has none to offer
        XCTAssertNil(SpaceIdentity.uuid(forIndex: 3, in: spaces))
        XCTAssertNil(SpaceIdentity.uuid(forIndex: 9, in: spaces))
    }
}
