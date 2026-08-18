import XCTest

final class ProfileTests: XCTestCase {
    private let spaces = [
        SpaceIdentityEntry(uuid: "space-a", index: 1),
        SpaceIdentityEntry(uuid: "space-b", index: 2),
    ]

    func testAnUnboundProfileSwitchesNowhereAndKeepsItsApps() {
        let profile = Profile(name: "Coding", appBundleIds: ["com.apple.dt.Xcode"], layout: "leftTwoThirds")
        let plan = ProfileActivation.plan(profile, spaces: spaces)
        XCTAssertNil(plan.switchToSpaceIndex)
        XCTAssertFalse(plan.bindingLost)
        XCTAssertEqual(plan.filterToBundleIds, ["com.apple.dt.Xcode"])
    }

    func testABoundProfileResolvesToItsSpaceIndex() {
        let plan = ProfileActivation.plan(Profile(name: "Research", spaceUuid: "space-b"), spaces: spaces)
        XCTAssertEqual(plan.switchToSpaceIndex, 2)
        XCTAssertFalse(plan.bindingLost)
    }

    /// The safety rule: a binding to a space that no longer exists is reported, never repointed.
    func testALostBindingIsReportedAndSwitchesNowhere() {
        let plan = ProfileActivation.plan(Profile(name: "Meeting", spaceUuid: "space-gone"), spaces: spaces)
        XCTAssertNil(plan.switchToSpaceIndex)
        XCTAssertTrue(plan.bindingLost)
    }

    func testProfileRoundTripsThroughJson() throws {
        let profile = Profile(name: "Coding", appBundleIds: ["a", "b"], layout: "leftThird", spaceUuid: "space-a")
        let data = try JSONEncoder().encode(profile)
        XCTAssertEqual(try JSONDecoder().decode(Profile.self, from: data), profile)
    }
}
