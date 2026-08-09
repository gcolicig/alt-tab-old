import XCTest

final class PointerOwnershipTests: XCTestCase {
    private let baseline = 3.0
    private let desired = -1.0

    private func acquired() -> PointerOwnershipRecord {
        let begun = PointerOwnershipPolicy.beginAcquisition(.unmanaged, current: baseline, desired: desired)!
        return PointerOwnershipPolicy.confirmWrite(begun, readBack: desired)
    }

    func testAcquisitionRecordsTheIntentBeforeTouchingTheSystem() {
        let begun = PointerOwnershipPolicy.beginAcquisition(.unmanaged, current: baseline, desired: desired)
        XCTAssertEqual(begun?.pendingWrite, desired)
        XCTAssertEqual(begun?.baseline, baseline)
        // not managed until the read-back confirms it
        XCTAssertEqual(begun?.state, .unmanaged)
    }

    func testAcquisitionIsRefusedWhileAlreadyManaged() {
        XCTAssertNil(PointerOwnershipPolicy.beginAcquisition(acquired(), current: baseline, desired: desired))
    }

    func testConfirmedWriteBecomesManagedAndClearsThePendingValue() {
        let record = acquired()
        XCTAssertEqual(record.state, .managed)
        XCTAssertEqual(record.lastWritten, desired)
        XCTAssertEqual(record.baseline, baseline)
        XCTAssertNil(record.pendingWrite)
    }

    func testReadBackDisagreeingWithTheWriteFailsClosed() {
        let begun = PointerOwnershipPolicy.beginAcquisition(.unmanaged, current: baseline, desired: desired)!
        let record = PointerOwnershipPolicy.confirmWrite(begun, readBack: 1.5)
        XCTAssertEqual(record.state, .relinquished)
        XCTAssertNil(record.baseline)
        XCTAssertNil(record.lastWritten)
    }

    func testAFailedWriteLeavesOwnershipUntaken() {
        let begun = PointerOwnershipPolicy.beginAcquisition(.unmanaged, current: baseline, desired: desired)!
        let record = PointerOwnershipPolicy.abandonWrite(begun)
        XCTAssertEqual(record.state, .unmanaged)
        XCTAssertNil(record.pendingWrite)
    }

    func testCanonicalisationAbsorbsTheRoundingTheSystemApplies() {
        XCTAssertTrue(PointerOwnershipPolicy.equal(0.6875, 0.68750000001))
        XCTAssertFalse(PointerOwnershipPolicy.equal(0.6875, 0.6975))
        XCTAssertFalse(PointerOwnershipPolicy.equal(nil, 0.6875))
    }

    func testAForeignChangeWhileManagedRelinquishesWithoutWritingBack() {
        let record = PointerOwnershipPolicy.detectForeignChange(acquired(), current: 2.5)
        XCTAssertEqual(record.state, .relinquished)
        XCTAssertNil(record.lastWritten)
    }

    func testAnUnchangedValueWhileManagedKeepsOwnership() {
        let record = acquired()
        XCTAssertEqual(PointerOwnershipPolicy.detectForeignChange(record, current: desired), record)
    }

    func testRelinquishedSurvivesAndBlocksReapply() {
        let relinquished = PointerOwnershipPolicy.detectForeignChange(acquired(), current: 2.5)
        XCTAssertEqual(PointerOwnershipPolicy.reapply(relinquished, current: 2.5, desired: desired), .relinquish)
    }

    func testReacquisitionFromRelinquishedTakesTheCurrentValueAsTheNewBaseline() {
        let relinquished = PointerOwnershipPolicy.detectForeignChange(acquired(), current: 2.5)
        let begun = PointerOwnershipPolicy.beginAcquisition(relinquished, current: 2.5, desired: desired)
        XCTAssertEqual(begun?.baseline, 2.5)
        XCTAssertEqual(PointerOwnershipPolicy.confirmWrite(begun!, readBack: desired).baseline, 2.5)
    }

    func testReapplyWritesOnlyWhileTheValueIsStillOurs() {
        let record = acquired()
        XCTAssertEqual(PointerOwnershipPolicy.reapply(record, current: desired, desired: 2.0), .write(2.0))
        XCTAssertEqual(PointerOwnershipPolicy.reapply(record, current: desired, desired: desired), .alreadyCorrect)
        XCTAssertEqual(PointerOwnershipPolicy.reapply(record, current: 2.5, desired: desired), .relinquish)
        XCTAssertEqual(PointerOwnershipPolicy.reapply(.unmanaged, current: baseline, desired: desired), .relinquish)
    }

    func testDisableRestoresTheBaselineOnlyWhenTheValueIsStillOurs() {
        XCTAssertEqual(PointerOwnershipPolicy.disable(acquired(), current: desired), .restore(baseline))
        XCTAssertEqual(PointerOwnershipPolicy.disable(acquired(), current: 2.5), .relinquishWithoutRestore)
        XCTAssertEqual(PointerOwnershipPolicy.disable(.unmanaged, current: baseline), .nothingToRestore)
    }

    func testACleanRestoreEndsAsUnmanagedAndAFailedOneAsRelinquished() {
        XCTAssertEqual(PointerOwnershipPolicy.afterRestore(acquired(), succeeded: true), .unmanaged)
        XCTAssertEqual(PointerOwnershipPolicy.afterRestore(acquired(), succeeded: false).state, .relinquished)
    }

    func testCrashRecoveryRestoresOnlyUnderEqualityWithTheLastWrittenValue() {
        XCTAssertEqual(PointerOwnershipPolicy.recover(acquired(), current: desired), .restore(baseline))
        XCTAssertEqual(PointerOwnershipPolicy.recover(acquired(), current: 2.5), .relinquishWithoutRestore)
        XCTAssertEqual(PointerOwnershipPolicy.recover(.unmanaged, current: baseline), .nothingToDo)
    }

    func testAnAbortBetweenWriteAndReadBackIsAttributableOnlyByThePendingValue() {
        let begun = PointerOwnershipPolicy.beginAcquisition(.unmanaged, current: baseline, desired: desired)!
        XCTAssertEqual(PointerOwnershipPolicy.recover(begun, current: desired), .restore(baseline))
        XCTAssertEqual(PointerOwnershipPolicy.recover(begun, current: 2.5), .relinquishWithoutRestore)
    }

    func testSystemDefaultOwnsNothingWhileTheOtherModesProduceAValue() {
        XCTAssertNil(PointerAccelerationMode.systemDefault.desiredValue(speed: 3))
        XCTAssertEqual(PointerAccelerationMode.disabled.desiredValue(speed: 3), -1)
        XCTAssertEqual(PointerAccelerationMode.custom.desiredValue(speed: 0.6875), 0.6875)
    }

    func testSpeedStepsClampAndRoundTrip() {
        XCTAssertEqual(PointerSpeedSteps.value(-5), PointerSpeedSteps.values.first)
        XCTAssertEqual(PointerSpeedSteps.value(999), PointerSpeedSteps.values.last)
        XCTAssertEqual(PointerSpeedSteps.value(4), 0.6875)
        XCTAssertEqual(PointerSpeedSteps.nearestIndex(0.6875), 4)
        XCTAssertEqual(PointerSpeedSteps.nearestIndex(3), PointerSpeedSteps.maximumIndex)
    }

    /// A value the system already holds need not sit on a notch, so taking ownership has to snap.
    func testNearestIndexSnapsAValueBetweenTwoNotches() {
        XCTAssertEqual(PointerSpeedSteps.value(PointerSpeedSteps.nearestIndex(0.7)), 0.6875)
        XCTAssertEqual(PointerSpeedSteps.value(PointerSpeedSteps.nearestIndex(2.4)), 2.5)
    }

    /// The keys the HID system answers to. The NSGlobalDomain names this once asserted were readable but
    /// writing them changed nothing, which is what moved this module to the HID path.
    func testAccelerationKeysMatchTheHidSystemKeys() {
        XCTAssertEqual(PointerCategory.mouse.accelerationKey, "HIDMouseAcceleration")
        XCTAssertEqual(PointerCategory.trackpad.accelerationKey, "HIDTrackpadAcceleration")
    }
}
