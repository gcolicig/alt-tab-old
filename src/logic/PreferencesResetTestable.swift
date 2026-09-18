import Foundation

/// Pure logic behind `Preferences.reset(keys:)`, split out so it is reachable from the unit-tests
/// target, which mocks `Preferences` itself (see unit-tests/Mocks.swift) and cannot see the real one.
enum PreferencesResetLogic {
    /// Of the requested keys, only those with a registered default are safe to reset — an unknown
    /// or misspelled key is ignored rather than touching an unrelated UserDefaults entry.
    static func resettableKeys(requested: [String], knownDefaultKeys: Set<String>) -> [String] {
        requested.filter { knownDefaultKeys.contains($0) }
    }
}
