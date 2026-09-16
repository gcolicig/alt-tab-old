import Cocoa

/// Story 14L. macOS asks the user to confirm the change itself; AltTab+ never works around that prompt.
enum DefaultBrowser {
    private static let probeUrl = URL(string: "https://example.com")!

    static func installed() -> [URL] {
        guard #available(macOS 12.0, *) else { return [] }
        let candidates = NSWorkspace.shared.urlsForApplications(toOpen: probeUrl).map { (bundleId: bundleId($0), path: $0.path) }
        return DefaultBrowserActionId.uniqueApps(candidates) { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0)?.path }
            .map { URL(fileURLWithPath: $0.path) }
            .sorted { displayName($0).localizedCaseInsensitiveCompare(displayName($1)) == .orderedAscending }
    }

    static func current() -> URL? {
        NSWorkspace.shared.urlForApplication(toOpen: probeUrl)
    }

    static func displayName(_ appUrl: URL) -> String {
        FileManager.default.displayName(atPath: appUrl.path).replacingOccurrences(of: ".app", with: "")
    }

    static func bundleId(_ appUrl: URL) -> String? {
        Bundle(url: appUrl)?.bundleIdentifier
    }

    static func url(forBundleId bundleId: String) -> URL? {
        installed().first { self.bundleId($0) == bundleId }
    }

    static func isCurrent(_ bundleId: String) -> Bool {
        current().flatMap(self.bundleId) == bundleId
    }

    static func set(bundleId: String) {
        guard let appUrl = url(forBundleId: bundleId) else { return NSSound.beep() }
        set(appUrl)
    }

    static func set(_ appUrl: URL) {
        guard #available(macOS 12.0, *) else { return }
        NSWorkspace.shared.setDefaultApplication(at: appUrl, toOpenURLsWithScheme: "http") { error in
            if let error { Logger.warning { "Setting the default browser failed: \(error)" } }
        }
    }
}
