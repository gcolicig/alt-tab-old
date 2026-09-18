import Cocoa

struct SettingsSectionDefinition {
    let id: String
    let title: String
    let description: String
    let imageName: String
    let systemSymbolName: String
    let view: NSView
    /// Rebuilds this page's content view from scratch. Used by "Reset to defaults" to redraw a
    /// page's controls after their backing preferences are restored, since a control's initial
    /// state is read once at construction and does not observe later preference changes.
    let builder: () -> NSView
}

final class SettingsSearchHighlightTarget {
    private let matchRanges: (String) -> [Range<Int>]
    private let applyHighlight: ([Range<Int>]) -> Void
    private let clearHighlight: () -> Void

    init(_ matchRanges: @escaping (String) -> [Range<Int>], _ applyHighlight: @escaping ([Range<Int>]) -> Void, _ clearHighlight: @escaping () -> Void) {
        self.matchRanges = matchRanges
        self.applyHighlight = applyHighlight
        self.clearHighlight = clearHighlight
    }

    convenience init(_ hasMatch: @escaping (String) -> Bool, _ applyHighlight: @escaping () -> Void, _ clearHighlight: @escaping () -> Void) {
        self.init({ query in
            hasMatch(query) ? [0..<1] : []
        }, { _ in
            applyHighlight()
        }, clearHighlight)
    }

    func hasMatch(_ query: String) -> Bool {
        !matchRanges(query).isEmpty
    }

    func updateHighlight(_ query: String) {
        let ranges = matchRanges(query)
        if ranges.isEmpty {
            clearHighlight()
        } else {
            applyHighlight(ranges)
        }
    }

    func clear() {
        clearHighlight()
    }
}

final class SettingsSection {
    let id: String
    let title: String
    let icon: NSImage
    let container: NSView
    let anchor: NSView
    /// Rebuilt in place by `rebuildContent()`, so search re-indexes the page after a reset.
    private(set) var searchableStrings: [String]
    private(set) var highlightTargets: [SettingsSearchHighlightTarget]
    let interSectionSpacingConstraint: NSLayoutConstraint
    let bottomSpacingConstraint: NSLayoutConstraint
    let titleTopConstraint: NSLayoutConstraint
    /// Preference keys this page's controls expose, as found by `SettingsResetKeysCollector`.
    /// Empty for pages with nothing to reset (e.g. a page of pure informational text).
    let resettableKeys: [String]
    /// Swaps this page's content view for a freshly built one and re-indexes search content.
    /// `nil` when re-running the page's builder is not safe (see `SettingsWindow.addSection`).
    private let rebuildContent: (() -> Void)?
    /// Breadcrumb shown above the title while searching (e.g. "Switcher › Cmd-Tab › Animations").
    /// Collapsed to zero height outside of search via `pathLabelHeightConstraint`.
    private let pathLabel: NSTextField
    private let pathLabelHeightConstraint: NSLayoutConstraint
    private let pathToTitleSpacingConstraint: NSLayoutConstraint

    var canResetToDefaults: Bool { rebuildContent != nil && !resettableKeys.isEmpty }

    /// Restores `resettableKeys` to their defaults and redraws the page's controls to reflect it.
    func resetToDefaults() {
        Preferences.reset(keys: resettableKeys)
        rebuildContent?()
    }

    /// Called by `rebuildContent` once the page's content view has been swapped, so settings
    /// search re-indexes the new controls instead of the ones that were just discarded.
    func updateSearchContent(_ searchableStrings: [String], _ highlightTargets: [SettingsSearchHighlightTarget]) {
        self.searchableStrings = searchableStrings
        self.highlightTargets = highlightTargets
    }

    init(_ id: String,
         _ title: String,
         _ icon: NSImage,
         _ container: NSView,
         _ anchor: NSView,
         _ searchableStrings: [String],
         _ highlightTargets: [SettingsSearchHighlightTarget],
         _ interSectionSpacingConstraint: NSLayoutConstraint,
         _ bottomSpacingConstraint: NSLayoutConstraint,
         _ titleTopConstraint: NSLayoutConstraint,
         _ pathLabel: NSTextField,
         _ pathLabelHeightConstraint: NSLayoutConstraint,
         _ pathToTitleSpacingConstraint: NSLayoutConstraint,
         _ resettableKeys: [String],
         _ rebuildContent: (() -> Void)?) {
        self.id = id
        self.title = title
        self.icon = icon
        self.container = container
        self.anchor = anchor
        self.searchableStrings = searchableStrings
        self.highlightTargets = highlightTargets
        self.interSectionSpacingConstraint = interSectionSpacingConstraint
        self.bottomSpacingConstraint = bottomSpacingConstraint
        self.titleTopConstraint = titleTopConstraint
        self.pathLabel = pathLabel
        self.pathLabelHeightConstraint = pathLabelHeightConstraint
        self.resettableKeys = resettableKeys
        self.rebuildContent = rebuildContent
        self.pathToTitleSpacingConstraint = pathToTitleSpacingConstraint
    }

    func matches(_ query: String) -> Bool {
        if SettingsSearch.isQueryEmpty(query) { return true }
        if searchableStrings.contains(where: { SettingsSearch.match(query, in: $0) != nil }) { return true }
        return highlightTargets.contains { $0.hasMatch(query) }
    }

    func highlightMatches(_ query: String) {
        highlightTargets.forEach { $0.updateHighlight(query) }
    }

    func clearHighlights() {
        highlightTargets.forEach { $0.clear() }
    }

    /// `nil` or empty hides the breadcrumb and collapses its height back to zero.
    func updateSearchPath(_ path: String?) {
        guard let path, !path.isEmpty else {
            pathLabel.isHidden = true
            pathLabel.stringValue = ""
            pathLabelHeightConstraint.isActive = true
            pathToTitleSpacingConstraint.constant = 0
            return
        }
        pathLabel.stringValue = path
        pathLabel.isHidden = false
        pathLabelHeightConstraint.isActive = false
        pathToTitleSpacingConstraint.constant = 4
    }
}
