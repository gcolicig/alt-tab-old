import Foundation

/// Pure logic behind `Preferences.reset(keys:)`, split out so it is reachable from the unit-tests
/// target, which mocks `Preferences` itself (see unit-tests/Mocks.swift) and cannot see the real one.
enum PreferencesResetLogic {
    /// Of the requested keys, only those with a registered default are safe to reset — an unknown
    /// or misspelled key is ignored rather than touching an unrelated UserDefaults entry.
    static func resettableKeys(requested: [String], knownDefaultKeys: Set<String>) -> [String] {
        requested.filter { knownDefaultKeys.contains($0) }
    }

    /// Enumerates the indexed keys a page writes through a control with no `identifier` the view-tree
    /// collector can see (e.g. Leader's per-slot action popup, FlickRing's per-direction popup), by
    /// filtering the full set of registered default keys down to those starting with `prefix`. Sorted so
    /// the result is deterministic regardless of dictionary iteration order.
    static func keysWithPrefix(_ prefix: String, in defaultValues: [String: Any]) -> [String] {
        defaultValues.keys.filter { $0.hasPrefix(prefix) }.sorted()
    }
}
