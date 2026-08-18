import Foundation

/// 1-based position of a space in the current session. Volatile — it shifts on reorder/create/delete — which
/// is why the stable UUID exists alongside it. Defined here so both the app and test targets see it.
typealias SpaceIndex = Int

/// One space as the identity resolver sees it: its stable managed-space UUID (nil when the space exposes
/// none) and its current 1-based index. The index is session-local and shifts when spaces are reordered,
/// created, or deleted; the UUID is what survives.
struct SpaceIdentityEntry: Equatable {
    let uuid: String?
    let index: SpaceIndex
}

/// Resolves between a stable space UUID and the volatile index the switch actions use. It never guesses:
/// a UUID that no current space carries resolves to nil, so a binding to a deleted space (or one from
/// another machine) is reported lost instead of being bent onto a random space.
enum SpaceIdentity {
    static func index(forUuid uuid: String, in spaces: [SpaceIdentityEntry]) -> SpaceIndex? {
        spaces.first { $0.uuid == uuid }?.index
    }

    static func uuid(forIndex index: SpaceIndex, in spaces: [SpaceIdentityEntry]) -> String? {
        spaces.first { $0.index == index }?.uuid
    }

    /// True when some current space still carries this UUID; the settings UI marks a binding whose UUID is
    /// absent so the user sees it rather than having it silently repointed.
    static func isPresent(_ uuid: String, in spaces: [SpaceIdentityEntry]) -> Bool {
        index(forUuid: uuid, in: spaces) != nil
    }
}
