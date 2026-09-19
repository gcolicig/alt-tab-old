import Cocoa
import ShortcutRecorder

/// Runs the Leader module on top of the existing keyboard tap. The tap already covers keyDown for the whole
/// app, so Leader adds no second tap, no arming marker, and no circuit breaker of its own: a hung callback
/// here is the same tap's problem, handled by the same recovery.
///
/// The trigger arms a session; while a session collects keys, every keyDown is fed to the pure
/// `LeaderSession` state machine and absorbed. An action is only ever produced here — it runs on the main
/// thread, off the tap callback (Q-16).
enum LeaderController {
    static let triggerPreferenceKey = "leaderTriggerShortcut"

    private static let lock = NSLock()
    private static var state = LeaderSessionState.idle
    private static var trie = LeaderTrie()
    /// Bumped on every state change so a scheduled timeout only fires for the session it was armed for.
    private static var generation: UInt64 = 0

    static var isEnabled: Bool {
        Preferences.leaderEnabled
            && Preferences.shortcut(triggerPreferenceKey) != nil
            && !Preferences.inputModulesSafeMode
    }

    // MARK: - runtime, called from the keyboard tap (background thread)

    /// Returns true when Leader consumed the key. Idle: only the trigger arms a session. Collecting: every
    /// key belongs to Leader until it runs, aborts, or times out.
    ///
    /// Autorepeat never counts as a key. A trigger held past the repeat delay (225 ms at the shortest macOS
    /// setting) sent a repeated trigger into the fresh session, which aborted it before the overlay was seen
    /// (measured 2026-09-17). Repeats are absorbed instead.
    static func handleKeyDown(_ keyCode: UInt32, _ modifiers: NSEvent.ModifierFlags, isAutorepeat: Bool = false) -> Bool {
        guard isEnabled else { return false }
        return lock.withLock {
            switch state {
                case .idle:
                    guard matchesTrigger(keyCode, modifiers) else { return false }
                    if !isAutorepeat { beginLocked() }
                    return true
                case .collecting where isAutorepeat:
                    return true
                case .collecting(let sequence):
                    let key = LeaderKey(keyCode: keyCode, modifiers: sequenceModifiers(modifiers))
                    switch LeaderSession.accept(.collecting(sequence), key: key, in: trie) {
                        case .keepCollecting(let next):
                            state = .collecting(next)
                            armLocked()
                        case .run(let identifier):
                            endLocked()
                            DispatchQueue.main.async { Actions.perform(identifier) }
                        case .abort:
                            endLocked()
                    }
                    return true
            }
        }
    }

    /// Called from every path that must leave nothing armed: module disabled, safe mode, the emergency
    /// shortcut, sleep/wake.
    static func reset() {
        lock.withLock { endLocked() }
    }

    static func rebuildTrie() {
        let built = LeaderBindingsStore.trie()
        lock.withLock {
            trie = built
            // a live session was walking the old trie; drop it rather than continue against new bindings
            endLocked()
        }
    }

    // MARK: - locked helpers (call with `lock` held)

    private static func beginLocked() {
        state = LeaderSession.begin()
        armLocked()
    }

    private static func armLocked() {
        generation &+= 1
        let session = generation
        let sequence = collectingSequence()
        DispatchQueue.main.async { showOverlay(for: sequence) }
        DispatchQueue.main.asyncAfter(deadline: .now() + LeaderSession.timeout) { timeoutFired(session) }
    }

    private static func endLocked() {
        generation &+= 1
        state = .idle
        DispatchQueue.main.async { LeaderPanel.hide() }
    }

    private static func collectingSequence() -> [LeaderKey] {
        if case .collecting(let sequence) = state { return sequence }
        return []
    }

    // MARK: - timeout and overlay (main thread)

    private static func timeoutFired(_ session: UInt64) {
        lock.withLock {
            guard session == generation, case .collecting = state else { return }
            endLocked()
        }
    }

    private static func showOverlay(for sequence: [LeaderKey]) {
        let snapshot = lock.withLock { trie }
        guard let level = snapshot.level(after: sequence) else {
            LeaderPanel.hide()
            return
        }
        let options = level
            .map { key, node -> LeaderPanel.Option in
                switch node {
                    case .action(let id):
                        return LeaderPanel.Option(key: display(key), label: title(id), isGroup: false)
                    case .group(let children):
                        // "more…" said nothing about what waits behind the key; the actions do
                        return LeaderPanel.Option(key: display(key), label: groupLabel(children), isGroup: true)
                }
            }
            .sorted { $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending }
        LeaderPanel.show(options)
    }

    /// What a key leads to, as far as it fits on one line: the actions below it, or how many there are.
    private static func groupLabel(_ children: [LeaderKey: LeaderNode]) -> String {
        let titles = actionTitles(children)
        guard titles.count > 2 else { return titles.joined(separator: ", ") }
        return String(format: NSLocalizedString("%d actions", comment: "Leader overlay"), titles.count)
    }

    private static func actionTitles(_ level: [LeaderKey: LeaderNode]) -> [String] {
        level.values.flatMap { node -> [String] in
            switch node {
                case .action(let id): return [title(id)]
                case .group(let children): return actionTitles(children)
            }
        }
    }

    private static func title(_ id: ActionIdentifier) -> String {
        Actions.registry.action(id)?.title() ?? ""
    }

    // MARK: - trigger matching and key display

    /// Keys typed with the trigger's modifiers still held count as plain keys. With a Hyper trigger, Caps Lock
    /// is easily still down when the first letter follows, and every such attempt aborted (measured 2026-09-17).
    private static func sequenceModifiers(_ modifiers: NSEvent.ModifierFlags) -> NSEvent.ModifierFlags {
        guard let trigger = Preferences.shortcut(triggerPreferenceKey) else { return modifiers }
        let held = modifiers.intersection(LeaderKey.relevantModifiers)
        let triggerModifiers = trigger.modifierFlags.intersection(LeaderKey.relevantModifiers)
        return !triggerModifiers.isEmpty && held == triggerModifiers ? modifiers.subtracting(triggerModifiers) : modifiers
    }

    private static func matchesTrigger(_ keyCode: UInt32, _ modifiers: NSEvent.ModifierFlags) -> Bool {
        guard let trigger = Preferences.shortcut(triggerPreferenceKey), trigger.keyCode != .none else { return false }
        let relevant = modifiers.intersection(LeaderKey.relevantModifiers)
        return UInt32(trigger.carbonKeyCode) == keyCode
            && trigger.modifierFlags.intersection(LeaderKey.relevantModifiers) == relevant
    }

    static func display(_ key: LeaderKey) -> String {
        guard let code = KeyCode(rawValue: CGKeyCode(key.keyCode)) else { return "?" }
        let shortcut = Shortcut(
            code: code,
            modifierFlags: NSEvent.ModifierFlags(rawValue: key.modifiers),
            characters: nil,
            charactersIgnoringModifiers: nil)
        return shortcut.readableStringRepresentation(isASCII: false)
    }
}
