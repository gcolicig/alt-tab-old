import XCTest

class TypingMuteTests: XCTestCase {
    private let hold: TimeInterval = 0.4

    private func armed() -> TypingMuteStateMachine {
        var state = TypingMuteStateMachine()
        state.isArmed = true
        return state
    }

    func testFreshKeyDownStartsAPhase() {
        var state = armed()
        XCTAssertEqual(state.key(.down(isAutorepeat: false), at: 10, hold: hold), .mute(generation: 1))
        XCTAssertTrue(state.isHolding)
        XCTAssertEqual(state.deadline, 10.4, accuracy: 1e-9)
    }

    func testNothingStartsWhenNotArmed() {
        var state = TypingMuteStateMachine()
        XCTAssertEqual(state.key(.down(isAutorepeat: false), at: 10, hold: hold), .none)
        XCTAssertFalse(state.isHolding)
    }

    func testAutorepeatKeyUpAndModifiersDoNotStartAPhase() {
        var state = armed()
        XCTAssertEqual(state.key(.down(isAutorepeat: true), at: 10, hold: hold), .none)
        XCTAssertEqual(state.key(.up, at: 10, hold: hold), .none)
        XCTAssertEqual(state.key(.modifiers, at: 10, hold: hold), .none)
        XCTAssertFalse(state.isHolding)
    }

    func testEveryKeyEventInsideAPhaseExtendsItWithoutAnotherMute() {
        var state = armed()
        _ = state.key(.down(isAutorepeat: false), at: 10, hold: hold)
        XCTAssertEqual(state.key(.up, at: 10.1, hold: hold), .none)
        XCTAssertEqual(state.key(.modifiers, at: 10.2, hold: hold), .none)
        XCTAssertEqual(state.key(.down(isAutorepeat: false), at: 10.3, hold: hold), .none)
        XCTAssertEqual(state.deadline, 10.7, accuracy: 1e-9)
    }

    func testTimerWaitsForAnExtendedDeadlineThenReleases() {
        var state = armed()
        _ = state.key(.down(isAutorepeat: false), at: 10, hold: 0.5)
        _ = state.key(.up, at: 10.25, hold: 0.5)
        XCTAssertEqual(state.timerFired(at: 10.5), .wait(until: 10.75))
        XCTAssertEqual(state.timerFired(at: 10.75), .release)
        XCTAssertFalse(state.isHolding)
        XCTAssertEqual(state.timerFired(at: 11), .stop)
    }

    func testEndingAPhaseInvalidatesAQueuedMute() {
        var state = armed()
        guard case .mute(let generation) = state.key(.down(isAutorepeat: false), at: 10, hold: hold) else { return XCTFail() }
        XCTAssertTrue(state.isCurrent(generation))
        XCTAssertTrue(state.end())
        XCTAssertFalse(state.isCurrent(generation))
        XCTAssertFalse(state.end())
        XCTAssertEqual(state.timerFired(at: 11), .stop)
    }

    func testANewPhaseAfterReleaseHasANewGeneration() {
        var state = armed()
        _ = state.key(.down(isAutorepeat: false), at: 10, hold: hold)
        _ = state.timerFired(at: 11)
        XCTAssertEqual(state.key(.down(isAutorepeat: false), at: 12, hold: hold), .mute(generation: 2))
    }

    func testDevicesTheUserAlreadySilencedAreNotTaken() {
        XCTAssertTrue(TypingMuteOwnership.canSilence(target(.volume, 0.7)))
        XCTAssertFalse(TypingMuteOwnership.canSilence(target(.volume, 0)))
        XCTAssertTrue(TypingMuteOwnership.canSilence(target(.mute, 0)))
        XCTAssertFalse(TypingMuteOwnership.canSilence(target(.mute, 1)))
    }

    func testOwningRemembersTheOriginalAndWritesSilence() {
        XCTAssertEqual(TypingMuteOwnership.own(target(.volume, 0.7)),
            TypingMuteOwnedDevice(device: 42, uid: "BuiltInMic", route: .volume, original: 0.7, written: 0))
        XCTAssertEqual(TypingMuteOwnership.own(target(.mute, 0)).written, 1)
    }

    func testRestoreGivesBackOnlyWhatNobodyElseChanged() {
        let owned = TypingMuteOwnership.own(target(.volume, 0.7))
        XCTAssertEqual(TypingMuteOwnership.restoreValue(owned, observed: 0), 0.7)
        XCTAssertNil(TypingMuteOwnership.restoreValue(owned, observed: 0.5))
        XCTAssertFalse(TypingMuteOwnership.isExternalChange(owned, observed: 0.0005))
        XCTAssertTrue(TypingMuteOwnership.isExternalChange(owned, observed: 0.3))
    }

    func testMarkerRoundTripsAndToleratesGarbage() {
        let devices = [TypingMuteOwnership.own(target(.volume, 0.7)), TypingMuteOwnership.own(target(.mute, 0))]
        XCTAssertEqual(TypingMuteOwnership.decodeMarker(TypingMuteOwnership.encodeMarker(devices)), devices)
        XCTAssertEqual(TypingMuteOwnership.decodeMarker("not json"), [])
    }

    func testLatencyKeepsTheLastSamplesPerDevice() {
        var latencies = TypingMuteLatencies()
        (1...(TypingMuteLatencies.capacity + 10)).forEach { latencies.record("BuiltInMic", Double($0)) }
        XCTAssertEqual(latencies.summary(), "BuiltInMic p50 111.0 ms p95 200.0 ms (n=200)")
        XCTAssertEqual(TypingMuteLatencies().summary(), "no samples")
    }

    private func target(_ route: TypingMuteRoute, _ value: Float32) -> TypingMuteTarget {
        TypingMuteTarget(device: 42, uid: "BuiltInMic", route: route, currentValue: value)
    }
}
