import Foundation

/// Drives `PointerOwnershipPolicy` against the real system and the persisted record. Every write to the
/// system is preceded by a persisted intent and followed by a canonical read-back, so an abort in between
/// stays attributable on the next launch.
enum PointerOwnership {
    static func record(_ category: PointerCategory) -> PointerOwnershipRecord {
        let json = CachedUserDefaults.string(preferenceKey(category))
        guard !json.isEmpty, let data = json.data(using: .utf8),
              let record = try? JSONDecoder().decode(PointerOwnershipRecord.self, from: data) else { return .unmanaged }
        return record
    }

    static func state(_ category: PointerCategory) -> PointerOwnershipState {
        record(category).state
    }

    static func preferenceKey(_ category: PointerCategory) -> String {
        "pointerOwnership\(category.rawValue.capitalized)"
    }

    /// Deliberate acquisition. The desired value is the only thing the user chose; the baseline is whatever
    /// the system holds at this moment, which is what a later disable restores.
    @discardableResult
    static func acquire(_ category: PointerCategory, desired: Double) -> Bool {
        guard let current = PointerSystemSettings.read(category) else { return false }
        guard let pending = PointerOwnershipPolicy.beginAcquisition(record(category), current: current, desired: desired) else { return false }
        persist(category, pending)
        guard let readBack = PointerSystemSettings.write(category, desired) else {
            persist(category, PointerOwnershipPolicy.abandonWrite(pending))
            return false
        }
        let confirmed = PointerOwnershipPolicy.confirmWrite(pending, readBack: readBack)
        persist(category, confirmed)
        return confirmed.isManaged
    }

    /// Changing the value while already managed goes through the same ownership check as everything else.
    @discardableResult
    static func update(_ category: PointerCategory, desired: Double) -> Bool {
        guard let current = PointerSystemSettings.read(category) else { return false }
        let checked = PointerOwnershipPolicy.detectForeignChange(record(category), current: current)
        guard checked.isManaged else {
            persist(category, checked)
            return false
        }
        guard case .write = PointerOwnershipPolicy.reapply(checked, current: current, desired: desired) else { return true }
        let pending = PointerOwnershipRecord(state: checked.state, baseline: checked.baseline, lastWritten: checked.lastWritten, pendingWrite: PointerOwnershipPolicy.canonical(desired))
        persist(category, pending)
        guard let readBack = PointerSystemSettings.write(category, desired) else {
            persist(category, PointerOwnershipPolicy.abandonWrite(pending))
            return false
        }
        let confirmed = PointerOwnershipPolicy.confirmWrite(pending, readBack: readBack)
        persist(category, confirmed)
        return confirmed.isManaged
    }

    static func release(_ category: PointerCategory) {
        guard let current = PointerSystemSettings.read(category) else { return }
        let stored = record(category)
        switch PointerOwnershipPolicy.disable(stored, current: current) {
            case .nothingToRestore: return
            case .relinquishWithoutRestore: persist(category, PointerOwnershipPolicy.afterRestore(stored, succeeded: false))
            case .restore(let baseline):
                let readBack = PointerSystemSettings.write(category, baseline)
                let succeeded = PointerOwnershipPolicy.equal(readBack, baseline)
                persist(category, PointerOwnershipPolicy.afterRestore(stored, succeeded: succeeded))
        }
    }

    /// Runs once at startup, before anything re-applies a value. A record still marked `managed` means the
    /// previous session did not shut down cleanly.
    static func recoverAfterUncleanExit() {
        PointerCategory.allCases.forEach { category in
            let stored = record(category)
            guard stored.state == .managed || stored.pendingWrite != nil else { return }
            guard let current = PointerSystemSettings.read(category) else { return }
            switch PointerOwnershipPolicy.recover(stored, current: current) {
                case .nothingToDo: return
                case .relinquishWithoutRestore: persist(category, PointerOwnershipPolicy.afterRestore(stored, succeeded: false))
                case .restore(let baseline):
                    let readBack = PointerSystemSettings.write(category, baseline)
                    persist(category, PointerOwnershipPolicy.afterRestore(stored, succeeded: PointerOwnershipPolicy.equal(readBack, baseline)))
            }
        }
    }

    /// Wake, login and device reconnect re-assert the value, but only while it is provably still ours.
    static func reapplyAfterSystemEvent() {
        PointerCategory.allCases.forEach { category in
            guard record(category).isManaged, let current = PointerSystemSettings.read(category) else { return }
            guard let desired = Preferences.pointerDesiredValue(category) else { return }
            switch PointerOwnershipPolicy.reapply(record(category), current: current, desired: desired) {
                case .alreadyCorrect: return
                case .relinquish: persist(category, PointerOwnershipPolicy.detectForeignChange(record(category), current: current))
                case .write: update(category, desired: desired)
            }
        }
    }

    private static func persist(_ category: PointerCategory, _ record: PointerOwnershipRecord) {
        guard let data = try? JSONEncoder().encode(record), let json = String(data: data, encoding: .utf8) else { return }
        Preferences.set(preferenceKey(category), json)
    }
}
