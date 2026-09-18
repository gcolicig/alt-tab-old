import Cocoa

/// Finds which of a settings page's controls can be reset, by walking its view tree for
/// `identifier` values that match a registered preference key. `LabelAndControl.setupControl`
/// stamps the pref key onto `control.identifier` at construction time, so this walk is the only
/// way to recover, from the view tree alone, which keys a given page actually exposes.
enum SettingsResetKeysCollector {
    /// Descends into every subview, including the (possibly collapsed/hidden) content of
    /// `DisclosureSection`s, since a disclosure keeps its content in the view tree even when closed.
    static func collectResettableKeys(in root: NSView) -> [String] {
        var seen = Set<String>()
        var keys = [String]()
        collect(root, &seen, &keys)
        return keys
    }

    private static func collect(_ view: NSView, _ seen: inout Set<String>, _ keys: inout [String]) {
        if let identifier = view.identifier?.rawValue,
           Preferences.defaultValues[identifier] != nil,
           seen.insert(identifier).inserted {
            keys.append(identifier)
        }
        view.subviews.forEach { collect($0, &seen, &keys) }
    }
}
