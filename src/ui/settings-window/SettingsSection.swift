import Cocoa

struct SettingsSectionDefinition {
    let id: String
    let title: String
    let description: String
    let imageName: String
    let systemSymbolName: String
    /// Builds this page's content view. Called once, on demand — the first time the page is
    /// selected, reached via search, or reached by the after-show idle chain — and again by
    /// "Reset to defaults" to redraw a page's controls after their backing preferences are
    /// restored, since a control's initial state is read once at construction and does not
    /// observe later preference changes.
    let builder: () -> NSView
    /// Preference keys this page writes through a control with no `identifier` for
    /// `SettingsResetKeysCollector` to find (e.g. Leader's per-slot action popup, FlickRing's
    /// per-direction popup). Merged with the collected keys when deciding what "Reset to Defaults"
    /// touches. Evaluated at click time, not at page-construction time.
    var extraResettableKeys: () -> [String] = { [] }
    /// Runs once after a reset has finished rebuilding the page, for side effects that are not tied
    /// to replaying a single control's change-action (e.g. rebuilding a cached lookup structure that
    /// a direct preference write, unlike an interactive edit, never triggers on its own).
    var afterReset: (() -> Void)? = nil
    /// Hides "Reset to Defaults" even when the page has resettable keys. For pages whose content is
    /// user-created data rather than settings (Profiles, Apps & URLs): resetting would delete that
    /// data instead of restoring a default.
    var hidesResetButton = false
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
    /// Recomputes, against the page's *current* content view, which preference keys it exposes
    /// (`SettingsResetKeysCollector` plus the page's declared `extraResettableKeys`). Kept lazy
    /// rather than a stored array: a page like Apps & URLs or Profiles rebuilds its own content
    /// independently of a reset, and a count captured once at window construction would go stale.
    private let resettableKeysProvider: () -> [String]
    var resettableKeys: [String] { resettableKeysProvider() }
    /// True for pages whose content is user-created data rather than settings (see
    /// `SettingsSectionDefinition.hidesResetButton`); the button never shows regardless of keys.
    private let hidesResetButton: Bool
    /// Swaps this page's content view for a freshly built one, re-indexes search content, and
    /// replays the normal change-action of every rebuilt control whose key is passed in, so a reset's
    /// side effects (e.g. releasing pointer ownership, clearing `AppleLanguages`) match an interactive
    /// edit instead of only clearing the preference. `nil` when re-running the page's builder is not
    /// safe (see `SettingsWindow.addSection`).
    private let rebuildContent: (([String]) -> Void)?
    /// Re-indexes search content from the page's current view without rebuilding it, for a page that
    /// mutates its own content in place outside of a reset (e.g. AppearanceTab's CustomizeStyle
    /// disclosure swapping its own content via `DisclosureSection.setContent`).
    private let reindex: () -> Void
    /// Re-evaluates whether "Reset to Defaults" should show, for a page whose rebuilt content can
    /// change which resettable keys it exposes (e.g. Shortcuts' filtered/regrouped rows).
    private let refreshResetButtonVisibilityAction: () -> Void
    /// Breadcrumb shown above the title while searching (e.g. "Switcher › Cmd-Tab › Animations").
    /// Collapsed to zero height outside of search via `pathLabelHeightConstraint`.
    private let pathLabel: NSTextField
    private let pathLabelHeightConstraint: NSLayoutConstraint
    private let pathToTitleSpacingConstraint: NSLayoutConstraint
    /// Builds this page's content view into its (already-placed) slot. `nil` once `isBuilt` is
    /// true; pages are built once, on demand.
    private let buildContentAction: () -> Void
    /// Settings pages are built on demand rather than all at once (see `SettingsWindow`). `false`
    /// until this page's content view has actually been constructed and pinned into its slot.
    private(set) var isBuilt = false

    var canResetToDefaults: Bool { rebuildContent != nil && !hidesResetButton && !resettableKeys.isEmpty }

    /// Builds this page's content view the first time it is needed: selection, a search that
    /// matches it, a reveal/jump into it, or the after-show idle chain. A no-op once built.
    func ensureBuilt() {
        guard !isBuilt else { return }
        isBuilt = true
        buildContentAction()
    }

    /// Restores `resettableKeys` to their defaults, redraws the page's controls to reflect it, and
    /// replays the change-action of every rebuilt control whose key was actually explicitly set
    /// (i.e. not already at its default) so extra side effects apply the same way an interactive
    /// edit would. Keys already at their default are left out of the replay so e.g. the language
    /// page's restart prompt does not fire when nothing on the page had been changed.
    func resetToDefaults() {
        guard isBuilt else { return }
        let keys = resettableKeys
        let changedKeys = keys.filter { Preferences.all[$0] != nil }
        Preferences.reset(keys: keys)
        rebuildContent?(changedKeys)
    }

    /// Re-indexes search content from the page's current view without rebuilding it. Used when a page
    /// mutates its own content outside of a reset (see `reindex`).
    func reindexSearchContent() {
        reindex()
        refreshResetButtonVisibilityAction()
    }

    /// Called by `rebuildContent`/`reindex` once the page's content view has changed, so settings
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
         _ resettableKeysProvider: @escaping () -> [String],
         _ hidesResetButton: Bool,
         _ rebuildContent: (([String]) -> Void)?,
         _ reindex: @escaping () -> Void,
         _ buildContentAction: @escaping () -> Void,
         _ refreshResetButtonVisibility: @escaping () -> Void = {}) {
        self.buildContentAction = buildContentAction
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
        self.resettableKeysProvider = resettableKeysProvider
        self.hidesResetButton = hidesResetButton
        self.rebuildContent = rebuildContent
        self.reindex = reindex
        self.refreshResetButtonVisibilityAction = refreshResetButtonVisibility
        self.pathToTitleSpacingConstraint = pathToTitleSpacingConstraint
    }

    func matches(_ query: String) -> Bool {
        if SettingsSearch.isQueryEmpty(query) { return true }
        if searchableStrings.contains(where: { SettingsSearch.match(query, in: $0) != nil }) { return true }
        return highlightTargets.contains { $0.hasMatch(query) }
    }

    func highlightMatches(_ query: String) {
        guard SettingsSidebarLayout.shouldHighlightMatches(query) else { return clearHighlights() }
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
