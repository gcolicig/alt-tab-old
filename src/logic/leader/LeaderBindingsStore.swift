import Foundation

/// Reads Leader bindings from the fixed settings slots and folds them into the trie the controller walks.
/// Each slot holds a typed key sequence (US-ANSI letters/digits) and one action `stableId`; an empty or
/// unparseable slot, or one bound to an action that no longer exists, is skipped rather than breaking the set.
enum LeaderBindingsStore {
    static func keysPreferenceKey(_ slot: Int) -> String { "leaderSlotKeys\(slot)" }
    static func actionPreferenceKey(_ slot: Int) -> String { "leaderSlotAction\(slot)" }

    static func bindings() -> [LeaderBinding] {
        (0..<Preferences.maxLeaderSlotCount).compactMap { slot in
            guard let keys = LeaderKeyParsing.parse(CachedUserDefaults.string(keysPreferenceKey(slot))),
                  let action = Actions.identifier(forStableId: CachedUserDefaults.string(actionPreferenceKey(slot))) else { return nil }
            return LeaderBinding(keys: keys, action: action)
        }
    }

    static func trie() -> LeaderTrie {
        switch LeaderTrie.build(from: bindings()) {
            case .success(let trie): return trie
            case .failure(let error):
                Logger.error { "Leader bindings do not form a valid trie: \(error)" }
                return LeaderTrie()
        }
    }

    /// A user-facing reason the current slots are not usable as configured, or nil when they are fine. Covers
    /// a slot with text that does not parse, a slot with keys but no action, and an ambiguous set.
    static func validationMessage() -> String? {
        for slot in 0..<Preferences.maxLeaderSlotCount {
            let text = CachedUserDefaults.string(keysPreferenceKey(slot)).trimmingCharacters(in: .whitespaces)
            let hasAction = !CachedUserDefaults.string(actionPreferenceKey(slot)).isEmpty
            if !text.isEmpty, LeaderKeyParsing.parse(text) == nil {
                return NSLocalizedString("A sequence uses keys other than letters and digits.", comment: "")
            }
            if !text.isEmpty != hasAction {
                return NSLocalizedString("A row is missing either its keys or its action.", comment: "")
            }
        }
        if case .failure = LeaderTrie.build(from: bindings()) {
            return NSLocalizedString("Two sequences conflict: one is a prefix of another, or they are equal.", comment: "")
        }
        return nil
    }
}
