import Foundation

/// Pointer scaling is global system state, so AltTab+ may only write it while it provably still owns the
/// value it last wrote. Every decision below is pure: the caller supplies the persisted record and the value
/// currently in the system, and gets back what to do. Nothing here reads defaults or touches the system.
enum PointerCategory: String, CaseIterable {
    case mouse
    case trackpad

    /// The scaling key in NSGlobalDomain. Verified present on macOS 26.5.1 (build 25F80).
    var scalingKey: String {
        switch self {
            case .mouse: return "com.apple.mouse.scaling"
            case .trackpad: return "com.apple.trackpad.scaling"
        }
    }
}

/// macOS exposes tracking speed as a discrete slider, not a free value, and the scaling numbers behind its
/// notches are what a restore has to be able to reproduce. Storing the notch index keeps the preference an
/// integer, which is what the settings slider binds to, while the value written to the system stays exact.
enum PointerSpeedSteps {
    static let values = [0.0, 0.125, 0.3125, 0.5, 0.6875, 0.875, 1.0, 1.5, 2.0, 2.5, 3.0]

    static var maximumIndex: Int { values.count - 1 }

    static func value(_ index: Int) -> Double {
        values[min(max(index, 0), maximumIndex)]
    }

    /// Used when taking ownership of a value the system already holds, which need not sit on a notch.
    static func nearestIndex(_ value: Double) -> Int {
        values.enumerated().min { abs($0.element - value) < abs($1.element - value) }?.offset ?? 0
    }
}

enum PointerOwnershipState: String, Codable {
    case unmanaged
    case managed
    case relinquished
}

/// macOS encodes both settings in the one scaling value: a negative value turns acceleration off, any
/// positive value is the pointer speed. So the two settings from the backlog map onto a single number,
/// and `systemDefault` means AltTab+ owns nothing at all rather than writing some neutral value.
enum PointerAccelerationMode: String, Codable {
    case systemDefault
    case disabled
    case custom

    static let accelerationDisabledValue = -1.0

    func desiredValue(speed: Double) -> Double? {
        switch self {
            case .systemDefault: return nil
            case .disabled: return PointerAccelerationMode.accelerationDisabledValue
            case .custom: return speed
        }
    }
}

/// `baseline` is the system value from the start of the current ownership period, not from the first ever
/// activation: every new deliberate acquisition captures its own.
struct PointerOwnershipRecord: Equatable, Codable {
    var state: PointerOwnershipState
    var baseline: Double?
    var lastWritten: Double?
    /// Set before the system is touched and cleared after the canonical read-back, so an abort in between
    /// stays attributable on the next launch.
    var pendingWrite: Double?

    static let unmanaged = PointerOwnershipRecord(state: .unmanaged, baseline: nil, lastWritten: nil, pendingWrite: nil)

    var isManaged: Bool { state == .managed }
}

enum PointerReapplyDecision: Equatable {
    case write(Double)
    case alreadyCorrect
    case relinquish
}

enum PointerDisableDecision: Equatable {
    case restore(Double)
    case nothingToRestore
    case relinquishWithoutRestore
}

enum PointerRecoveryDecision: Equatable {
    case restore(Double)
    case relinquishWithoutRestore
    case nothingToDo
}

enum PointerOwnershipPolicy {
    /// Values come back from the system rounded or transformed, so equality is decided on a canonical form
    /// rather than on raw doubles.
    static func canonical(_ value: Double) -> Double {
        (value * 10000).rounded() / 10000
    }

    static func equal(_ a: Double?, _ b: Double?) -> Bool {
        guard let a = a, let b = b else { return false }
        return canonical(a) == canonical(b)
    }

    /// Step one of a deliberate acquisition: record the intent before the system is written.
    static func beginAcquisition(_ record: PointerOwnershipRecord, current: Double, desired: Double) -> PointerOwnershipRecord? {
        guard record.state != .managed else { return nil }
        return PointerOwnershipRecord(state: record.state, baseline: canonical(current), lastWritten: record.lastWritten, pendingWrite: canonical(desired))
    }

    /// Step two: the canonical read-back completes the acquisition.
    static func confirmWrite(_ record: PointerOwnershipRecord, readBack: Double) -> PointerOwnershipRecord {
        guard equal(record.pendingWrite, readBack) else { return failClosed(record) }
        return PointerOwnershipRecord(state: .managed, baseline: record.baseline, lastWritten: canonical(readBack), pendingWrite: nil)
    }

    /// The write itself failed, so the system was never changed and ownership is simply not taken.
    static func abandonWrite(_ record: PointerOwnershipRecord) -> PointerOwnershipRecord {
        PointerOwnershipRecord(state: record.state, baseline: nil, lastWritten: record.lastWritten, pendingWrite: nil)
    }

    /// A change AltTab+ did not make means another owner: never write back, never fight it.
    static func detectForeignChange(_ record: PointerOwnershipRecord, current: Double) -> PointerOwnershipRecord {
        guard record.isManaged, !equal(record.lastWritten, current) else { return record }
        return failClosed(record)
    }

    /// Re-apply after wake, login or device reconnect is bound by the same ownership check as any write.
    static func reapply(_ record: PointerOwnershipRecord, current: Double, desired: Double) -> PointerReapplyDecision {
        guard record.isManaged else { return .relinquish }
        guard equal(record.lastWritten, current) else { return .relinquish }
        guard !equal(current, desired) else { return .alreadyCorrect }
        return .write(desired)
    }

    static func disable(_ record: PointerOwnershipRecord, current: Double) -> PointerDisableDecision {
        guard record.isManaged else { return .nothingToRestore }
        guard equal(record.lastWritten, current) else { return .relinquishWithoutRestore }
        guard let baseline = record.baseline else { return .relinquishWithoutRestore }
        return .restore(baseline)
    }

    /// A successful restore ends the ownership period cleanly; `relinquished` is reserved for a value that
    /// somebody else owns now.
    static func afterRestore(_ record: PointerOwnershipRecord, succeeded: Bool) -> PointerOwnershipRecord {
        succeeded ? .unmanaged : failClosed(record)
    }

    /// A `managed` record surviving a crash or SIGKILL. An abort between write and read-back is attributable
    /// only if the system still holds exactly the pending value.
    static func recover(_ record: PointerOwnershipRecord, current: Double) -> PointerRecoveryDecision {
        guard record.state == .managed || record.pendingWrite != nil else { return .nothingToDo }
        guard let baseline = record.baseline else { return .relinquishWithoutRestore }
        if let pending = record.pendingWrite {
            return equal(pending, current) ? .restore(baseline) : .relinquishWithoutRestore
        }
        guard equal(record.lastWritten, current) else { return .relinquishWithoutRestore }
        return .restore(baseline)
    }

    private static func failClosed(_ record: PointerOwnershipRecord) -> PointerOwnershipRecord {
        PointerOwnershipRecord(state: .relinquished, baseline: nil, lastWritten: nil, pendingWrite: nil)
    }
}
