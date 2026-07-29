import Cocoa

enum LaunchAppAction {
    static func shortcutPreferenceKey(_ index: Int) -> String { Preferences.indexToName("launchAppShortcut", index) }

    static func localizedTitle(_ index: Int) -> String {
        let name = Preferences.launchAppName(index)
        return name.isEmpty ? NSLocalizedString("Launch app", comment: "") : name
    }

    static func perform(_ index: Int) {
        guard let appUrl = applicationUrl(index) else { return }
        // launching an app that already runs returns its instance without focusing it, which reads as
        // "the shortcut did nothing"; bring it forward the same way the switcher does
        if let running = runningApplication(at: appUrl) {
            running.activate(options: .activateAllWindows)
            return
        }
        _ = try? NSWorkspace.shared.launchApplication(at: appUrl, configuration: [:])
    }

    private static func runningApplication(at appUrl: URL) -> NSRunningApplication? {
        NSWorkspace.shared.runningApplications.first {
            $0.bundleURL?.standardizedFileURL == appUrl.standardizedFileURL
        }
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
            return .unavailable(NSLocalizedString("No installed application matches this bundle identifier or name.", comment: ""))
        }
        return .available
    }

    /// true when a bundle identifier was entered but no such application is installed
    static func isMisconfigured(_ index: Int) -> Bool {
        let bundleIdentifier = Preferences.launchAppBundleIdentifier(index)
        return !bundleIdentifier.isEmpty && applicationUrl(index) == nil
    }

    private static func applicationUrl(_ index: Int) -> URL? {
        let value = Preferences.launchAppBundleIdentifier(index).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }
        if LaunchAppTarget.couldBeBundleIdentifier(value),
           let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: value) {
            return url
        }
        return applicationUrlByName(value)
    }

    /// Running apps are already in memory and cover the common case; only otherwise do we consult the
    /// indexed application folders.
    private static func applicationUrlByName(_ name: String) -> URL? {
        if let running = NSWorkspace.shared.runningApplications.first(where: {
            guard let localizedName = $0.localizedName else { return false }
            return LaunchAppTarget.matches(name, applicationName: localizedName)
        })?.bundleURL {
            return running
        }
        return applicationIndex()[LaunchAppTarget.normalizedName(name)]
    }

    /// Built once: scanning the application folders on every shortcut press would put disk I/O on the
    /// input path. A newly installed app is picked up on the next launch.
    private static func applicationIndex() -> [String: URL] {
        if let applicationsByName { return applicationsByName }
        var index = [String: URL]()
        let fileManager = FileManager.default
        let roots = [URL(fileURLWithPath: "/Applications"),
                     URL(fileURLWithPath: "/System/Applications"),
                     fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Applications")]
        roots.forEach { root in
            guard let entries = try? fileManager.contentsOfDirectory(at: root, includingPropertiesForKeys: nil) else { return }
            entries.forEach { entry in
                if entry.pathExtension == "app" {
                    index[LaunchAppTarget.normalizedName(entry.deletingPathExtension().lastPathComponent)] = entry
                } else if let nested = try? fileManager.contentsOfDirectory(at: entry, includingPropertiesForKeys: nil) {
                    // one level down covers Utilities and similar grouping folders
                    nested.filter { $0.pathExtension == "app" }.forEach {
                        index[LaunchAppTarget.normalizedName($0.deletingPathExtension().lastPathComponent)] = $0
                    }
                }
            }
        }
        applicationsByName = index
        return index
    }

    private static var applicationsByName: [String: URL]?
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
