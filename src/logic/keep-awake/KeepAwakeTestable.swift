import Foundation

enum KeepAwakeDuration: Int, CaseIterable {
    case indefinitely
    case minutes15
    case hour1
    case hours2
    case hours5

    var seconds: TimeInterval? {
        switch self {
            case .indefinitely: return nil
            case .minutes15: return 15 * 60
            case .hour1: return 3600
            case .hours2: return 2 * 3600
            case .hours5: return 5 * 3600
        }
    }

    var action: SystemAction {
        switch self {
            case .indefinitely: return .keepAwakeIndefinitely
            case .minutes15: return .keepAwake15Minutes
            case .hour1: return .keepAwake1Hour
            case .hours2: return .keepAwake2Hours
            case .hours5: return .keepAwake5Hours
        }
    }
}

/// A session keeps its end as a wall-clock date, so time spent asleep counts against it (story 10).
struct KeepAwakeSession: Equatable {
    var endsAt: Date?
    var keepDisplayAwake: Bool

    static func starting(_ duration: KeepAwakeDuration, keepDisplayAwake: Bool, now: Date) -> KeepAwakeSession {
        KeepAwakeSession(endsAt: duration.seconds.map { now.addingTimeInterval($0) }, keepDisplayAwake: keepDisplayAwake)
    }

    static func until(_ date: Date, keepDisplayAwake: Bool) -> KeepAwakeSession {
        KeepAwakeSession(endsAt: date, keepDisplayAwake: keepDisplayAwake)
    }

    func remaining(at now: Date) -> TimeInterval? {
        endsAt.map { max(0, $0.timeIntervalSince(now)) }
    }

    func isExpired(at now: Date) -> Bool {
        guard let endsAt else { return false }
        return endsAt <= now
    }

    /// An open-ended session stays open-ended.
    func extended(by seconds: TimeInterval, now: Date) -> KeepAwakeSession {
        guard let endsAt else { return self }
        var copy = self
        copy.endsAt = max(endsAt, now).addingTimeInterval(seconds)
        return copy
    }
}

enum KeepAwakeState: Equatable {
    case inactive
    case active
    case displayAllowedToSleep
    case batteryProtected
    case error
}

enum KeepAwakeClock {
    /// `h:mm`, minutes rounded up so a session never shows `0:00` while it is still running.
    static func format(_ remaining: TimeInterval) -> String {
        let minutes = Int((remaining / 60).rounded(.up))
        return String(format: "%d:%02d", minutes / 60, minutes % 60)
    }

    /// The next occurrence of this time of day, today or tomorrow.
    static func nextOccurrence(hour: Int, minute: Int, after now: Date, calendar: Calendar = .current) -> Date? {
        calendar.nextDate(after: now, matching: DateComponents(hour: hour, minute: minute, second: 0), matchingPolicy: .nextTime)
    }

    /// Battery protection ends a session on battery power at or below the threshold; 0 turns it off.
    static func batteryShouldEnd(level: Int?, onBattery: Bool, threshold: Int) -> Bool {
        guard threshold > 0, onBattery, let level else { return false }
        return level <= threshold
    }
}
