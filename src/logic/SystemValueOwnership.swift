import Foundation

/// A global system value AltTab+ may take over: pointer scaling, the window drag-on-gesture switch. These
/// are shared with System Settings and with other tools, so the rule is always the same — never write a
/// value that cannot be proven to still be the one AltTab+ last wrote.
///
/// Extracted from the pointer module when the modifier drag needed the identical model for a boolean.
/// Two copies of this state machine would drift, and the failure mode of a drifted copy is destroying a
/// setting somebody else owns.
protocol OwnedSystemValue: Equatable, Codable {
    /// The system may round or transform what it stores, so comparisons run on a canonical form.
    static func canonicalForm(_ value: Self) -> Self
}

extension Double: OwnedSystemValue {
    static func canonicalForm(_ value: Double) -> Double {
        (value * 10000).rounded() / 10000
    }
}

extension Bool: OwnedSystemValue {
    static func canonicalForm(_ value: Bool) -> Bool { value }
}

enum SystemValueOwnershipState: String, Codable {
    case unmanaged
    case managed
    case relinquished
}

/// `baseline` is the system value from the start of the current ownership period, not from the first ever
/// activation: every new deliberate acquisition captures its own.
struct SystemValueOwnershipRecord<Value: OwnedSystemValue>: Equatable, Codable {
    var state: SystemValueOwnershipState
    var baseline: Value?
    var lastWritten: Value?
    /// Set before the system is touched and cleared after the canonical read-back, so an abort in between
    /// stays attributable on the next launch.
    var pendingWrite: Value?

    static var unmanaged: Self {
        SystemValueOwnershipRecord(state: .unmanaged, baseline: nil, lastWritten: nil, pendingWrite: nil)
    }

    var isManaged: Bool { state == .managed }
}

enum SystemValueReapplyDecision<Value: OwnedSystemValue>: Equatable {
    case write(Value)
    case alreadyCorrect
    case relinquish
}

enum SystemValueDisableDecision<Value: OwnedSystemValue>: Equatable {
    case restore(Value)
    case nothingToRestore
    case relinquishWithoutRestore
}

enum SystemValueRecoveryDecision<Value: OwnedSystemValue>: Equatable {
    case restore(Value)
    case relinquishWithoutRestore
    case nothingToDo
}

enum SystemValueOwnership<Value: OwnedSystemValue> {
    typealias Record = SystemValueOwnershipRecord<Value>

    static func canonical(_ value: Value) -> Value {
        Value.canonicalForm(value)
    }

    static func equal(_ a: Value?, _ b: Value?) -> Bool {
        guard let a = a, let b = b else { return false }
        return canonical(a) == canonical(b)
    }

    /// Step one of a deliberate acquisition: record the intent before the system is written.
    static func beginAcquisition(_ record: Record, current: Value, desired: Value) -> Record? {
        guard record.state != .managed else { return nil }
        return Record(state: record.state, baseline: canonical(current), lastWritten: record.lastWritten, pendingWrite: canonical(desired))
    }

    /// Step two: the canonical read-back completes the acquisition.
    static func confirmWrite(_ record: Record, readBack: Value) -> Record {
        guard equal(record.pendingWrite, readBack) else { return failClosed() }
        return Record(state: .managed, baseline: record.baseline, lastWritten: canonical(readBack), pendingWrite: nil)
    }

    /// The write itself failed, so the system was never changed and ownership is simply not taken.
    static func abandonWrite(_ record: Record) -> Record {
        Record(state: record.state, baseline: nil, lastWritten: record.lastWritten, pendingWrite: nil)
    }

    /// A change AltTab+ did not make means another owner: never write back, never fight it.
    static func detectForeignChange(_ record: Record, current: Value) -> Record {
        guard record.isManaged, !equal(record.lastWritten, current) else { return record }
        return failClosed()
    }

    /// Re-apply after wake, login or device reconnect is bound by the same ownership check as any write.
    static func reapply(_ record: Record, current: Value, desired: Value) -> SystemValueReapplyDecision<Value> {
        guard record.isManaged else { return .relinquish }
        guard equal(record.lastWritten, current) else { return .relinquish }
        guard !equal(current, desired) else { return .alreadyCorrect }
        return .write(desired)
    }

    static func disable(_ record: Record, current: Value) -> SystemValueDisableDecision<Value> {
        guard record.isManaged else { return .nothingToRestore }
        guard equal(record.lastWritten, current) else { return .relinquishWithoutRestore }
        guard let baseline = record.baseline else { return .relinquishWithoutRestore }
        return .restore(baseline)
    }

    /// A successful restore ends the ownership period cleanly; `relinquished` is reserved for a value that
    /// somebody else owns now.
    static func afterRestore(_ record: Record, succeeded: Bool) -> Record {
        succeeded ? .unmanaged : failClosed()
    }

    /// A `managed` record surviving a crash or SIGKILL. An abort between write and read-back is attributable
    /// only if the system still holds exactly the pending value.
    static func recover(_ record: Record, current: Value) -> SystemValueRecoveryDecision<Value> {
        guard record.state == .managed || record.pendingWrite != nil else { return .nothingToDo }
        guard let baseline = record.baseline else { return .relinquishWithoutRestore }
        if let pending = record.pendingWrite {
            return equal(pending, current) ? .restore(baseline) : .relinquishWithoutRestore
        }
        guard equal(record.lastWritten, current) else { return .relinquishWithoutRestore }
        return .restore(baseline)
    }

    private static func failClosed() -> Record {
        Record(state: .relinquished, baseline: nil, lastWritten: nil, pendingWrite: nil)
    }
}
