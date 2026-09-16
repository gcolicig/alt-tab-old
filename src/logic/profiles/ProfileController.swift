import Cocoa

/// Runs a profile: activation switches to the bound space (if the binding still resolves) and turns on a
/// filter so the switcher shows only the profile's apps. Nothing is killed, hidden, started, or moved — those
/// stay separate opt-in actions (roadmap Phase 6). Activating the already-active profile toggles it off.
enum ProfileController {
    private static var activeIndex: Int?

    static var activeProfileIndex: Int? { activeIndex }

    static func title(_ index: Int) -> String {
        let name = ProfileStore.profile(index)?.name ?? ""
        return name.isEmpty ? defaultName(index) : name
    }

    static func defaultName(_ index: Int) -> String {
        String(format: NSLocalizedString("Profile %d", comment: ""), index + 1)
    }

    static func availability(_ index: Int) -> ActionAvailability {
        ProfileStore.profile(index) != nil
            ? .available
            : .unavailable(NSLocalizedString("This profile slot is empty.", comment: ""))
    }

    static func activate(_ index: Int) {
        guard let profile = ProfileStore.profile(index) else { return }
        // a second trigger of the active profile turns the filter off again
        if activeIndex == index {
            deactivate()
            return
        }
        let plan = ProfileActivation.plan(profile, spaces: Spaces.identitySnapshot())
        if plan.bindingLost {
            Logger.info { "profile \(index) (\(profile.name)) is bound to a space that no longer exists; not switching" }
        } else if let spaceIndex = plan.switchToSpaceIndex, spaceIndex != Spaces.currentSpaceIndex, (1...9).contains(spaceIndex) {
            Actions.perform(.space(.index(spaceIndex)))
        }
        activeIndex = index
        refreshSwitcher()
    }

    static func deactivate() {
        guard activeIndex != nil else { return }
        activeIndex = nil
        refreshSwitcher()
    }

    /// The switcher filter: with a profile active, only windows of its apps pass. A profile with no apps
    /// filters nothing, so it is a pure space switch. No active profile means every window passes.
    static func allows(_ window: Window) -> Bool {
        guard let activeIndex, let profile = ProfileStore.profile(activeIndex), !profile.appBundleIds.isEmpty else { return true }
        guard let bundleId = window.application.bundleIdentifier else { return false }
        return profile.appBundleIds.contains { !$0.isEmpty && (bundleId == $0 || bundleId.hasPrefix($0)) }
    }

    private static func refreshSwitcher() {
        DispatchQueue.main.async { Windows.refreshWhichWindowsToShowTheUser() }
    }
}
