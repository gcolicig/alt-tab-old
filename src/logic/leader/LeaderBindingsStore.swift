import Foundation

/// Persists Leader bindings as JSON and folds them into the trie the controller walks. Bindings are stored
/// flat, each action by its `ActionIdentifier.stableId`, so a binding to an action that no longer exists
/// resolves to nil and is dropped rather than breaking the whole set.
enum LeaderBindingsStore {
    /// The on-disk shape. `LeaderKey` is already Codable; the action is a stableId string.
    private struct StoredBinding: Codable {
        let keys: [LeaderKey]
        let action: String
    }

    static func bindings() -> [LeaderBinding] {
        let json = CachedUserDefaults.string(LeaderController.bindingsPreferenceKey)
        guard !json.isEmpty,
              let data = json.data(using: .utf8),
              let stored = try? JSONDecoder().decode([StoredBinding].self, from: data) else { return [] }
        return stored.compactMap { entry in
            guard !entry.keys.isEmpty, let action = Actions.identifier(forStableId: entry.action) else { return nil }
            return LeaderBinding(keys: entry.keys, action: action)
        }
    }

    /// A stored set can still be ambiguous if it was written by an older or hand-edited build; a failed
    /// build yields an empty trie rather than a crash, and the settings editor is what keeps it valid.
    static func trie() -> LeaderTrie {
        switch LeaderTrie.build(from: bindings()) {
            case .success(let trie): return trie
            case .failure(let error):
                Logger.error { "Leader bindings do not form a valid trie: \(error)" }
                return LeaderTrie()
        }
    }

    static func save(_ bindings: [LeaderBinding]) {
        let stored = bindings.map { StoredBinding(keys: $0.keys, action: $0.action.stableId) }
        let json = (try? JSONEncoder().encode(stored)).flatMap { String(data: $0, encoding: .utf8) } ?? ""
        Preferences.set(LeaderController.bindingsPreferenceKey, json)
        LeaderController.rebuildTrie()
    }
}
