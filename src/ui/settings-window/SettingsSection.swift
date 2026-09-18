import Cocoa

struct SettingsSectionDefinition {
    let id: String
    let title: String
    let description: String
    let imageName: String
    let systemSymbolName: String
    let view: NSView
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
    let searchableStrings: [String]
    let highlightTargets: [SettingsSearchHighlightTarget]
    let interSectionSpacingConstraint: NSLayoutConstraint
    let bottomSpacingConstraint: NSLayoutConstraint
    let titleTopConstraint: NSLayoutConstraint
    /// Breadcrumb shown above the title while searching (e.g. "Switcher › Cmd-Tab › Animations").
    /// Collapsed to zero height outside of search via `pathLabelHeightConstraint`.
    private let pathLabel: NSTextField
    private let pathLabelHeightConstraint: NSLayoutConstraint
    private let pathToTitleSpacingConstraint: NSLayoutConstraint

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
         _ pathToTitleSpacingConstraint: NSLayoutConstraint) {
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
