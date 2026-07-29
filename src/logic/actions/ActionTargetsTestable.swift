import Foundation

/// Pure parsing of what the user types into an action slot. Kept free of `Preferences` and
/// `NSWorkspace` so the accepted spellings are pinned by tests rather than by trying inputs by hand.
struct OpenUrlTarget {
    /// Accepts what people actually type. `github.com` becomes `https://github.com`; anything that
    /// already carries a scheme is taken as written, so `mailto:` or a custom app scheme still works.
    /// Returns nil for input that is not a plausible target, which is what marks a slot misconfigured.
    static func normalized(_ raw: String) -> URL? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.contains(" ") else { return nil }
        if let url = URL(string: trimmed), let scheme = url.scheme, !scheme.isEmpty {
            return url
        }
        // no scheme: only treat it as a host when it actually looks like one, so a stray word does not
        // silently turn into a web address
        guard let dot = trimmed.firstIndex(of: "."), dot != trimmed.startIndex, trimmed.last != "." else { return nil }
        return URL(string: "https://" + trimmed)
    }
}
