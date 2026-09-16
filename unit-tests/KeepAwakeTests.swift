import XCTest

class KeepAwakeTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_000_000)

    func testTimedSessionEndsOnTheWallClock() {
        let session = KeepAwakeSession.starting(.hour1, keepDisplayAwake: false, now: now)
        XCTAssertEqual(session.remaining(at: now.addingTimeInterval(600)), 3000)
        XCTAssertFalse(session.isExpired(at: now.addingTimeInterval(3599)))
        XCTAssertTrue(session.isExpired(at: now.addingTimeInterval(3600)))
    }

    func testIndefiniteSessionNeverExpiresAndStaysOpenWhenExtended() {
        let session = KeepAwakeSession.starting(.indefinitely, keepDisplayAwake: true, now: now)
        XCTAssertNil(session.remaining(at: now))
        XCTAssertFalse(session.isExpired(at: now.addingTimeInterval(1e9)))
        XCTAssertNil(session.extended(by: 3600, now: now).endsAt)
    }

    func testExtendingAddsToTheLaterOfEndAndNow() {
        let session = KeepAwakeSession.starting(.minutes15, keepDisplayAwake: false, now: now)
        XCTAssertEqual(session.extended(by: 3600, now: now).endsAt, now.addingTimeInterval(900 + 3600))
        XCTAssertEqual(session.extended(by: 60, now: now.addingTimeInterval(5000)).endsAt, now.addingTimeInterval(5060))
    }

    func testRemainingTimeFormatRoundsUp() {
        XCTAssertEqual(KeepAwakeClock.format(5040), "1:24")
        XCTAssertEqual(KeepAwakeClock.format(1), "0:01")
        XCTAssertEqual(KeepAwakeClock.format(0), "0:00")
    }

    func testNextOccurrenceRollsOverToTomorrow() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let noon = calendar.date(from: DateComponents(year: 2026, month: 9, day: 16, hour: 12))!
        XCTAssertEqual(KeepAwakeClock.nextOccurrence(hour: 13, minute: 30, after: noon, calendar: calendar),
                       calendar.date(from: DateComponents(year: 2026, month: 9, day: 16, hour: 13, minute: 30)))
        XCTAssertEqual(KeepAwakeClock.nextOccurrence(hour: 9, minute: 0, after: noon, calendar: calendar),
                       calendar.date(from: DateComponents(year: 2026, month: 9, day: 17, hour: 9)))
    }

    func testBatteryProtection() {
        XCTAssertTrue(KeepAwakeClock.batteryShouldEnd(level: 20, onBattery: true, threshold: 20))
        XCTAssertFalse(KeepAwakeClock.batteryShouldEnd(level: 20, onBattery: false, threshold: 20))
        XCTAssertFalse(KeepAwakeClock.batteryShouldEnd(level: 5, onBattery: true, threshold: 0))
        XCTAssertFalse(KeepAwakeClock.batteryShouldEnd(level: nil, onBattery: true, threshold: 20))
    }
}
