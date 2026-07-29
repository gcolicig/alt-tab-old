import Cocoa

enum LaunchAppAction {
    static func shortcutPreferenceKey(_ index: Int) -> String { Preferences.indexToName("launchAppShortcut", index) }

    static func localizedTitle(_ index: Int) -> String {
        let name = Preferences.launchAppName(index)
        return name.isEmpty ? NSLocalizedString("Launch app", comment: "") : name
    }

    static func perform(_ index: Int) {
        guard let appUrl = applicationUrl(index) else { return }
        _ = try? NSWorkspace.shared.launchApplication(at: appUrl, configuration: [:])
    }

    static func availability(_ index: Int) -> ActionAvailability {
        guard !Preferences.inputModulesSafeMode else {
            return .unavailable(NSLocalizedString("Input extensions are in safe mode.", comment: ""))
        }
        let bundleIdentifier = Preferences.launchAppBundleIdentifier(index)
        guard !bundleIdentifier.isEmpty else {
            return .unavailable(NSLocalizedString("No application is configured.", comment: ""))
        }
        guard applicationUrl(index) != nil else {
            return .unavailable(NSLocalizedString("The application is not installed.", comment: ""))
        }
        return .available
    }

    /// true when a bundle identifier was entered but no such application is installed
    static func isMisconfigured(_ index: Int) -> Bool {
        let bundleIdentifier = Preferences.launchAppBundleIdentifier(index)
        return !bundleIdentifier.isEmpty && applicationUrl(index) == nil
    }

    private static func applicationUrl(_ index: Int) -> URL? {
        let bundleIdentifier = Preferences.launchAppBundleIdentifier(index)
        guard !bundleIdentifier.isEmpty else { return nil }
        return NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier)
    }
}

enum OpenUrlAction {
    static func shortcutPreferenceKey(_ index: Int) -> String { Preferences.indexToName("openUrlShortcut", index) }

    static func localizedTitle(_ index: Int) -> String {
        let name = Preferences.openUrlName(index)
        return name.isEmpty ? NSLocalizedString("Open URL", comment: "") : name
    }

    static func perform(_ index: Int) {
        guard let url = targetUrl(index) else { return }
        NSWorkspace.shared.open(url)
    }

    static func availability(_ index: Int) -> ActionAvailability {
        guard !Preferences.inputModulesSafeMode else {
            return .unavailable(NSLocalizedString("Input extensions are in safe mode.", comment: ""))
        }
        guard !Preferences.openUrlValue(index).isEmpty else {
            return .unavailable(NSLocalizedString("No URL is configured.", comment: ""))
        }
        guard targetUrl(index) != nil else {
            return .unavailable(NSLocalizedString("The URL is invalid.", comment: ""))
        }
        return .available
    }

    /// true when a value was entered but it is not a valid URL
    static func isMisconfigured(_ index: Int) -> Bool {
        let value = Preferences.openUrlValue(index)
        return !value.isEmpty && targetUrl(index) == nil
    }

    private static func targetUrl(_ index: Int) -> URL? {
        OpenUrlTarget.normalized(Preferences.openUrlValue(index))
    }
}
