import Cocoa

enum Actions {
    /// Built once: every entry reads its own mutable state through closures, so the registry itself
    /// never goes stale and must not be rebuilt on the shortcut path.
    static let registry = ActionRegistry(
        WindowLayoutAction.allCases.map(windowLayoutRegistration) +
            DisplayMoveAction.allCases.map(displayMoveRegistration) +
            SpaceAction.all.map(spaceRegistration) +
            (0..<Preferences.maxLaunchAppCount).map(launchAppRegistration) +
            (0..<Preferences.maxOpenUrlCount).map(openUrlRegistration) +
            (0..<Preferences.maxProfileCount).map(profileRegistration) +
            SystemActions.all.map(systemRegistration) +
            Array(Set(DefaultBrowser.installed().compactMap(DefaultBrowser.bundleId))).sorted().map(defaultBrowserRegistration)
    )

    /// A browser installed after launch has no registration; its binding still works.
    @discardableResult
    static func perform(_ id: ActionIdentifier) -> Bool {
        if case .defaultBrowser(let bundleId) = id, registry.action(id) == nil {
            DefaultBrowser.set(bundleId: bundleId)
            return true
        }
        return registry.perform(id)
    }

    /// Resolves the string in `ActionIdentifier.stableId` back to an identifier. Leader and FlickRing store
    /// their bindings by this string, so a binding to an action that no longer exists resolves to nil and is
    /// dropped instead of crashing.
    static func identifier(forStableId stableId: String) -> ActionIdentifier? {
        byStableId[stableId] ?? DefaultBrowserActionId.bundleId(fromStableId: stableId).map(ActionIdentifier.defaultBrowser)
    }

    private static let byStableId: [String: ActionIdentifier] = {
        var map = [String: ActionIdentifier]()
        registry.registeredActions.forEach { map[$0.id.stableId] = $0.id }
        return map
    }()

    private static func windowLayoutRegistration(_ action: WindowLayoutAction) -> RegisteredAction {
        RegisteredAction(id: .windowLayout(action), title: { action.localizedTitle }, availability: windowLayoutAvailability) {
            WindowLayouts.perform(action)
        }
    }

    private static func displayMoveRegistration(_ action: DisplayMoveAction) -> RegisteredAction {
        RegisteredAction(id: .displayMove(action), title: { action.localizedTitle }, availability: displayMoveAvailability) {
            WindowLayouts.perform(action)
        }
    }

    private static func displayMoveAvailability() -> ActionAvailability {
        guard NSScreen.screens.count > 1 else {
            return .unavailable(NSLocalizedString("Only one display is connected.", comment: ""))
        }
        return windowLayoutAvailability()
    }

    private static func spaceRegistration(_ action: SpaceAction) -> RegisteredAction {
        RegisteredAction(id: .space(action), title: { action.localizedTitle }, availability: { InstantSpaces.availability(action) }) {
            InstantSpaces.perform(action)
        }
    }

    private static func launchAppRegistration(_ index: Int) -> RegisteredAction {
        RegisteredAction(id: .launchApp(index), title: { LaunchAppAction.localizedTitle(index) }, availability: { LaunchAppAction.availability(index) }) {
            LaunchAppAction.perform(index)
        }
    }

    private static func openUrlRegistration(_ index: Int) -> RegisteredAction {
        RegisteredAction(id: .openUrl(index), title: { OpenUrlAction.localizedTitle(index) }, availability: { OpenUrlAction.availability(index) }) {
            OpenUrlAction.perform(index)
        }
    }

    private static func profileRegistration(_ index: Int) -> RegisteredAction {
        RegisteredAction(id: .activateProfile(index), title: { ProfileController.title(index) }, availability: { ProfileController.availability(index) }) {
            ProfileController.activate(index)
        }
    }

    private static func systemRegistration(_ spec: SystemActionSpec) -> RegisteredAction {
        RegisteredAction(id: .system(spec.action), title: { spec.title }, availability: spec.availability, execute: spec.perform)
    }

    private static func defaultBrowserRegistration(_ bundleId: String) -> RegisteredAction {
        RegisteredAction(id: .defaultBrowser(bundleId),
            title: { String(format: NSLocalizedString("Set Default Browser: %@", comment: ""), DefaultBrowser.url(forBundleId: bundleId).map(DefaultBrowser.displayName) ?? bundleId) },
            availability: { DefaultBrowser.url(forBundleId: bundleId) == nil ? .unavailable(NSLocalizedString("The browser is not installed.", comment: "")) : .available }) {
            DefaultBrowser.set(bundleId: bundleId)
        }
    }

    private static func windowLayoutAvailability() -> ActionAvailability {
        guard !Preferences.inputModulesSafeMode else {
            return .unavailable(NSLocalizedString("Input extensions are in safe mode.", comment: ""))
        }
        guard !App.appIsBeingUsed else {
            return .unavailable(NSLocalizedString("Close the window switcher before arranging a window.", comment: ""))
        }
        guard AXIsProcessTrusted() else {
            return .unavailable(NSLocalizedString("Accessibility permission is required.", comment: ""))
        }
        guard let frontmostApplication = NSWorkspace.shared.frontmostApplication,
              frontmostApplication.processIdentifier != ProcessInfo.processInfo.processIdentifier else {
            return .unavailable(NSLocalizedString("No eligible foreground application.", comment: ""))
        }
        return .available
    }
}
