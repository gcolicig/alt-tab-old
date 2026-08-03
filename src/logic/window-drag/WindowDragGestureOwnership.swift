import Cocoa

/// `Command+Control` can only drive the modifier move while the global `NSWindowShouldDragOnGesture` switch
/// is off: with it on, macOS already drags background windows on that combination and the two fight over the
/// same mouse down.
///
/// The switch is global system state like the pointer scaling, so it goes through the same ownership model:
/// baseline captured on deliberate acquisition, canonical read-back, restore only while the value is still
/// the one AltTab+ wrote, and a crash leaving the record behind is recovered before anything re-applies.
enum WindowDragGestureOwnership {
    static let key = "NSWindowShouldDragOnGesture"
    private static let preferenceKey = "windowDragGestureOwnership"
    private typealias Ownership = SystemValueOwnership<Bool>

    /// Reading a value macOS has never written yields nil. That is not the same as `false`: an absent key
    /// means the system default applies, and the default is what a restore has to put back.
    static func read() -> Bool? {
        CFPreferencesCopyValue(key as CFString, kCFPreferencesAnyApplication, kCFPreferencesCurrentUser, kCFPreferencesAnyHost) as? Bool
    }

    private static func write(_ value: Bool) -> Bool? {
        CFPreferencesSetValue(key as CFString, value as CFBoolean, kCFPreferencesAnyApplication, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        guard CFPreferencesSynchronize(kCFPreferencesAnyApplication, kCFPreferencesCurrentUser, kCFPreferencesAnyHost) else { return nil }
        return read()
    }

    static func record() -> SystemValueOwnershipRecord<Bool> {
        let json = CachedUserDefaults.string(preferenceKey)
        guard !json.isEmpty, let data = json.data(using: .utf8),
              let record = try? JSONDecoder().decode(SystemValueOwnershipRecord<Bool>.self, from: data) else { return .unmanaged }
        return record
    }

    static var isSatisfied: Bool {
        read() == false
    }

    /// Called before `Command+Control` may arm. Returns false when the switch could not be turned off or
    /// verified, which per the backlog leaves the modifier unavailable rather than half-working.
    /// `deliberate` is true only when the user just picked the modifier. Coming back from `relinquished`
    /// requires that: the state exists precisely to record that somebody else owns the value now, and
    /// silently retaking it at every launch would defeat it.
    @discardableResult
    static func acquire(deliberate: Bool) -> Bool {
        let stored = record()
        guard stored.state != .relinquished || deliberate else { return false }
        // already off without us: nothing to own, and nothing to restore later
        if read() == false, !stored.isManaged { return true }
        let current = read() ?? true
        guard let pending = Ownership.beginAcquisition(stored, current: current, desired: false) else { return isSatisfied }
        persist(pending)
        guard let readBack = write(false) else {
            persist(Ownership.abandonWrite(pending))
            return false
        }
        let confirmed = Ownership.confirmWrite(pending, readBack: readBack)
        persist(confirmed)
        return confirmed.isManaged
    }

    static func release() {
        let stored = record()
        guard let current = read() ?? Optional(false) else { return }
        switch Ownership.disable(stored, current: current) {
            case .nothingToRestore: return
            case .relinquishWithoutRestore: persist(Ownership.afterRestore(stored, succeeded: false))
            case .restore(let baseline):
                let readBack = write(baseline)
                persist(Ownership.afterRestore(stored, succeeded: Ownership.equal(readBack, baseline)))
        }
    }

    /// Runs at startup before the module may arm, so an unclean exit cannot leave the user's system switch
    /// silently turned off.
    ///
    /// Returns true when a record from a previous session had to be dealt with. The caller must then leave
    /// the module switched off: restoring the value and immediately taking it again in the same launch
    /// would undo the restore, which is exactly what happened before this returned anything.
    @discardableResult
    static func recoverAfterUncleanExit() -> Bool {
        let stored = record()
        guard stored.state == .managed || stored.pendingWrite != nil else { return false }
        guard let current = read() ?? Optional(false) else { return false }
        switch Ownership.recover(stored, current: current) {
            case .nothingToDo: return false
            case .relinquishWithoutRestore:
                persist(Ownership.afterRestore(stored, succeeded: false))
            case .restore(let baseline):
                let readBack = write(baseline)
                persist(Ownership.afterRestore(stored, succeeded: Ownership.equal(readBack, baseline)))
        }
        return true
    }

    private static func persist(_ record: SystemValueOwnershipRecord<Bool>) {
        guard let data = try? JSONEncoder().encode(record), let json = String(data: data, encoding: .utf8) else { return }
        Preferences.set(preferenceKey, json)
    }
}
