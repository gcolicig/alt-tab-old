import Foundation

/// A project profile: a stable AltTab+ object, not a macOS space. It names a set of apps and optionally a
/// layout and a bound space, and it survives a space being deleted or renumbered because the binding is a
/// stable UUID, resolved only when the profile is activated.
struct Profile: Codable, Equatable {
    var name: String
    /// Bundle identifiers the profile groups; activation filters or prioritises the switcher to these.
    var appBundleIds: [String]
    /// A `WindowLayoutAction` raw value, or nil for no layout.
    var layout: String?
    /// A managed-space UUID this profile is bound to, or nil for no binding. Never rewritten on activation.
    var spaceUuid: String?

    init(name: String = "", appBundleIds: [String] = [], layout: String? = nil, spaceUuid: String? = nil) {
        self.name = name
        self.appBundleIds = appBundleIds
        self.layout = layout
        self.spaceUuid = spaceUuid
    }

    var isEmpty: Bool { name.isEmpty && appBundleIds.isEmpty && layout == nil && spaceUuid == nil }
}

/// What activating a profile should do, decided without touching the system so it can be tested. The runtime
/// then switches the space (if any), applies the filter, and surfaces a lost binding.
struct ProfileActivationPlan: Equatable {
    /// The current index of the bound space, or nil when the profile has no binding or its binding is lost.
    let switchToSpaceIndex: SpaceIndex?
    /// The profile is bound to a UUID that no current space carries: show it, do not switch anywhere.
    let bindingLost: Bool
    /// The bundle identifiers to filter or prioritise in the switcher.
    let filterToBundleIds: [String]
}

enum ProfileActivation {
    /// Resolves a profile against the current spaces. A bound-but-missing space never falls back to another
    /// space — it is reported lost — so a profile whose space was deleted does not yank the user elsewhere.
    static func plan(_ profile: Profile, spaces: [SpaceIdentityEntry]) -> ProfileActivationPlan {
        let index = profile.spaceUuid.flatMap { SpaceIdentity.index(forUuid: $0, in: spaces) }
        let bindingLost = profile.spaceUuid != nil && index == nil
        return ProfileActivationPlan(switchToSpaceIndex: index, bindingLost: bindingLost, filterToBundleIds: profile.appBundleIds)
    }
}
