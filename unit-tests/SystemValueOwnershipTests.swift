import XCTest

/// The pointer tests already cover this state machine over Double. These pin the boolean instantiation the
/// modifier drag uses for NSWindowShouldDragOnGesture, where the interesting part is that `false` is a
/// meaningful owned value rather than an absence.
final class SystemValueOwnershipTests: XCTestCase {
    private typealias Ownership = SystemValueOwnership<Bool>

    private func acquired(from baseline: Bool = true) -> SystemValueOwnershipRecord<Bool> {
        let begun = Ownership.beginAcquisition(.unmanaged, current: baseline, desired: false)!
        return Ownership.confirmWrite(begun, readBack: false)
    }

    func testTakingOverATrueSwitchRecordsItAsTheBaseline() {
        let record = acquired()
        XCTAssertEqual(record.state, .managed)
        XCTAssertEqual(record.baseline, true)
        XCTAssertEqual(record.lastWritten, false)
        XCTAssertNil(record.pendingWrite)
    }

    func testDisableRestoresTheSwitchOnlyWhileItIsStillOurs() {
        XCTAssertEqual(Ownership.disable(acquired(), current: false), .restore(true))
        // somebody turned it back on: restoring would be writing over their choice
        XCTAssertEqual(Ownership.disable(acquired(), current: true), .relinquishWithoutRestore)
    }

    func testAForeignChangeRelinquishesInsteadOfFightingForTheSwitch() {
        XCTAssertEqual(Ownership.detectForeignChange(acquired(), current: true).state, .relinquished)
        XCTAssertEqual(Ownership.detectForeignChange(acquired(), current: false), acquired())
    }

    func testCrashRecoveryRestoresOnlyUnderEquality() {
        XCTAssertEqual(Ownership.recover(acquired(), current: false), .restore(true))
        XCTAssertEqual(Ownership.recover(acquired(), current: true), .relinquishWithoutRestore)
        XCTAssertEqual(Ownership.recover(.unmanaged, current: false), .nothingToDo)
    }

    func testAnAbortBetweenWriteAndReadBackStaysAttributable() {
        let begun = Ownership.beginAcquisition(.unmanaged, current: true, desired: false)!
        XCTAssertEqual(Ownership.recover(begun, current: false), .restore(true))
        XCTAssertEqual(Ownership.recover(begun, current: true), .relinquishWithoutRestore)
    }

    /// A baseline that was already false is still owned: without recording it, a later restore would have
    /// nothing to put back and could leave the switch off for good.
    func testABaselineThatWasAlreadyFalseIsStillRestored() {
        XCTAssertEqual(Ownership.disable(acquired(from: false), current: false), .restore(false))
    }
}

extension SystemValueOwnershipTests {
    /// The whole point of `relinquished`: an automatic path must not take the value back. Only a fresh
    /// deliberate activation may, and it then treats the current value as its new baseline.
    func testReacquisitionFromRelinquishedStartsANewOwnershipPeriod() {
        let relinquished = SystemValueOwnership<Bool>.detectForeignChange(acquiredForReacquisition(), current: true)
        XCTAssertEqual(relinquished.state, .relinquished)
        XCTAssertNil(relinquished.baseline)
        let begun = SystemValueOwnership<Bool>.beginAcquisition(relinquished, current: true, desired: false)
        XCTAssertEqual(begun?.baseline, true)
        XCTAssertEqual(SystemValueOwnership<Bool>.confirmWrite(begun!, readBack: false).state, .managed)
    }

    private func acquiredForReacquisition() -> SystemValueOwnershipRecord<Bool> {
        let begun = SystemValueOwnership<Bool>.beginAcquisition(.unmanaged, current: true, desired: false)!
        return SystemValueOwnership<Bool>.confirmWrite(begun, readBack: false)
    }
}
