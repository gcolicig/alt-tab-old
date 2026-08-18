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
    static let bindingsPreferenceKey = "leaderBindings"

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
    static func handleKeyDown(_ keyCode: UInt32, _ modifiers: NSEvent.ModifierFlags) -> Bool {
        guard isEnabled else { return false }
        return lock.withLock {
            switch state {
                case .idle:
                    guard matchesTrigger(keyCode, modifiers) else { return false }
                    beginLocked()
                    return true
                case .collecting(let sequence):
                    let key = LeaderKey(keyCode: keyCode, modifiers: modifiers)
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
                        return LeaderPanel.Option(key: display(key), label: Actions.registry.action(id)?.title() ?? "", isGroup: false)
                    case .group:
                        return LeaderPanel.Option(key: display(key), label: NSLocalizedString("more…", comment: ""), isGroup: true)
                }
            }
            .sorted { $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending }
        LeaderPanel.show(options)
    }

    // MARK: - trigger matching and key display

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
