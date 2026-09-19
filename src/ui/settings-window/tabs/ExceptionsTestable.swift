import Cocoa

enum ExceptionHidePreference: String/* required for jsonEncode */, CaseIterable, Codable {
    case none = "0"
    case always = "1"
    case whenNoOpenWindow = "2"
    case windowTitleContains = "3"

    var localizedString: String {
        switch self {
            case .none: return NSLocalizedString("Show", comment: "")
            case .always: return NSLocalizedString("Hide", comment: "")
            case .whenNoOpenWindow: return NSLocalizedString("Hide without windows", comment: "")
            case .windowTitleContains: return NSLocalizedString("Hide by title", comment: "")
        }
    }
}

enum ExceptionIgnorePreference: String/* required for jsonEncode */, CaseIterable, Codable {
    case none = "0"
    case always = "1"
    case whenFullscreen = "2"

    var localizedString: String {
        switch self {
            case .none: return NSLocalizedString("Always on", comment: "")
            case .always: return NSLocalizedString("Off", comment: "")
            case .whenFullscreen: return NSLocalizedString("Off in full screen", comment: "")
        }
    }
}

struct ExceptionEntry: Codable {
    var bundleIdentifier: String
    var hide: ExceptionHidePreference
    var ignore: ExceptionIgnorePreference
    var windowTitleContains: String?
}

/// Pure helpers for the Exceptions page (`ExceptionsTab.swift`), split out so they can be unit
/// tested without constructing any AppKit views.
enum ExceptionsTestable {
    /// A bundle id ending with "." is a prefix entry: it matches every app whose bundle id starts
    /// with it (e.g. `com.parallels.`), not one specific app.
    static func isPrefix(_ bundleIdentifier: String) -> Bool {
        bundleIdentifier.hasSuffix(".")
    }

    /// The name shown on the left of a row: `<prefix>*` for a prefix entry (short enough to survive
    /// the shared row helpers' middle-truncation instead of wording that gets swallowed by it), the
    /// resolved app name when one was found, otherwise the raw bundle id as a fallback.
    static func displayName(bundleIdentifier: String, resolvedName: String?) -> String {
        if isPrefix(bundleIdentifier) {
            return bundleIdentifier + "*"
        }
        return resolvedName ?? bundleIdentifier
    }

    /// Appends a new entry with default preferences, after trimming whitespace and rejecting an
    /// empty or duplicate bundle id. Returns `nil` when nothing should be inserted.
    static func insert(_ entries: [ExceptionEntry], bundleIdentifier: String) -> [ExceptionEntry]? {
        let trimmed = bundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !entries.contains(where: { $0.bundleIdentifier == trimmed }) else { return nil }
        var result = entries
        result.append(ExceptionEntry(bundleIdentifier: trimmed, hide: .always, ignore: .none, windowTitleContains: nil))
        return result
    }

    /// Updates one entry in place. Only the passed-in fields change; `nil` leaves a field as-is.
    static func update(_ entries: [ExceptionEntry], at index: Int,
                        hide: ExceptionHidePreference? = nil,
                        ignore: ExceptionIgnorePreference? = nil,
                        title: String? = nil) -> [ExceptionEntry] {
        var result = entries
        guard entries.indices.contains(index) else { return result }
        if let hide { result[index].hide = hide }
        if let ignore { result[index].ignore = ignore }
        if let title { result[index].windowTitleContains = title }
        return result
    }

    static func remove(_ entries: [ExceptionEntry], at index: Int) -> [ExceptionEntry] {
        var result = entries
        guard entries.indices.contains(index) else { return result }
        result.remove(at: index)
        return result
    }
}
