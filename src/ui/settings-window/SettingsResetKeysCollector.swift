import Cocoa

/// Finds which of a settings page's controls can be reset, by walking its view tree for
/// `identifier` values that match a registered preference key. `LabelAndControl.setupControl`
/// stamps the pref key onto `control.identifier` at construction time, so this walk is the only
/// way to recover, from the view tree alone, which keys a given page actually exposes.
enum SettingsResetKeysCollector {
    /// Descends into every subview, including the (possibly collapsed/hidden) content of
    /// `DisclosureSection`s, since a disclosure keeps its content in the view tree even when closed.
    static func collectResettableKeys(in root: NSView) -> [String] {
        collectResettableControls(in: root).compactMap { $0.identifier?.rawValue }
    }

    /// Same walk as `collectResettableKeys`, but keeps the controls themselves so a reset can replay
    /// each one's normal change-action (see `LabelAndControl.controlWasChanged`/`extraAction`) after the
    /// page is rebuilt with default values, instead of only clearing the underlying preference.
    static func collectResettableControls(in root: NSView) -> [NSControl] {
        var seen = Set<String>()
        var controls = [NSControl]()
        collect(root, &seen, &controls)
        return controls
    }

    private static func collect(_ view: NSView, _ seen: inout Set<String>, _ controls: inout [NSControl]) {
        if let control = view as? NSControl,
           let identifier = control.identifier?.rawValue,
           Preferences.defaultValues[identifier] != nil,
           seen.insert(identifier).inserted {
            controls.append(control)
        }
        view.subviews.forEach { collect($0, &seen, &controls) }
    }
}
