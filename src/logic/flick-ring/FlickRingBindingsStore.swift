import Foundation

/// Maps each ring direction to a registry action. Each direction stores one `ActionIdentifier.stableId`, or
/// the empty string for "no action", so a direction bound to an action that no longer exists resolves to nil.
enum FlickRingBindingsStore {
    static func preferenceKey(_ direction: FlickDirection) -> String {
        switch direction {
            case .up: return "flickRingUp"
            case .right: return "flickRingRight"
            case .down: return "flickRingDown"
            case .left: return "flickRingLeft"
        }
    }

    static func action(for direction: FlickDirection) -> ActionIdentifier? {
        let stableId = CachedUserDefaults.string(preferenceKey(direction))
        guard !stableId.isEmpty else { return nil }
        return Actions.identifier(forStableId: stableId)
    }

    static func stableId(for direction: FlickDirection) -> String {
        CachedUserDefaults.string(preferenceKey(direction))
    }

    static func set(_ direction: FlickDirection, _ stableId: String?) {
        Preferences.set(preferenceKey(direction), stableId ?? "")
    }
}
