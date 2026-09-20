import Foundation

/// Story 16, stage 1: the sidebar groups and which page is shown.
enum SettingsSidebarGroup: String, CaseIterable {
    case app
    case switcher
    case windows
    case input
    case actions
}

enum SettingsSidebarRow: Equatable {
    case header(SettingsSidebarGroup)
    case section(String)

    var sectionId: String? {
        guard case .section(let id) = self else { return nil }
        return id
    }
}

enum SettingsSidebarLayout {
    /// Section ids per group, in display order. A section missing here is shown under `actions`, so a
    /// new section never disappears from the sidebar.
    static let sectionsByGroup: [(SettingsSidebarGroup, [String])] = [
        (.app, ["general"]),
        (.switcher, ["appearance", "controls", "exceptions"]),
        (.windows, ["window-layouts", "spaces", "profiles"]),
        (.input, ["shortcuts", "hyperkey", "leader", "flick-ring", "pointer-scroll"]),
        (.actions, ["system-actions", "keep-awake", "apps-urls"]),
    ]

    /// A 1-character query still filters pages (`SettingsSearch.match` keeps matching from length 1),
    /// but highlighting every occurrence of a single letter across a page is just noise. Highlighting
    /// only kicks in once the trimmed query reaches 2 characters.
    static func shouldHighlightMatches(_ query: String) -> Bool {
        query.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2
    }

    /// Every section id registered in `SettingsWindow.sectionDefinitions()`. Kept in sync with that
    /// function so a missing entry here is caught by an assertion instead of silently falling back to
    /// `.actions`.
    static let allSectionIds: [String] = [
        "general", "shortcuts", "appearance", "controls", "exceptions",
        "window-layouts", "spaces", "profiles",
        "hyperkey", "leader", "flick-ring", "pointer-scroll",
        "system-actions", "keep-awake", "apps-urls",
    ]

    static func group(of sectionId: String) -> SettingsSidebarGroup {
        sectionsByGroup.first { $0.1.contains(sectionId) }?.0 ?? .actions
    }

    /// Order the section definitions follow, so the stacked search results read like the sidebar.
    static func order(_ sectionIds: [String]) -> [String] {
        let known = sectionsByGroup.flatMap(\.1)
        let unknown = sectionIds.filter { !known.contains($0) }
        return known.filter { sectionIds.contains($0) } + unknown
    }

    /// A heading above each group that still has a visible section.
    static func rows(_ visibleSectionIds: [String]) -> [SettingsSidebarRow] {
        var rows = [SettingsSidebarRow]()
        for group in SettingsSidebarGroup.allCases {
            let ids = visibleSectionIds.filter { self.group(of: $0) == group }
            guard !ids.isEmpty else { continue }
            rows.append(.header(group))
            rows.append(contentsOf: ids.map { .section($0) })
        }
        return rows
    }

    /// Without a query one page is shown: the chosen one while it exists, else the first. With a query
    /// every matching section is shown, and the selection stays on the chosen page if it matches.
    static func selection(visible: [String], preferred: String?) -> String? {
        guard let preferred, visible.contains(preferred) else { return visible.first }
        return preferred
    }

    static func chosenSection(current: String?, selected: String, searching: Bool) -> String? {
        searching ? current : selected
    }

    static func displayed(all: [String], matching: [String], selected: String?, searching: Bool) -> [String] {
        guard searching else { return selected.map { [$0] } ?? [] }
        return all.filter { matching.contains($0) }
    }

    /// The breadcrumb shown above a page while searching, e.g. "Switcher › Cmd-Tab › Animations".
    /// `sectionTitles` are the disclosure sections (in the page) that contain a match; they are
    /// deduplicated in order and capped at 2, with "…" standing in for the rest, so a page with
    /// many matching sections still reads as a short, stable path.
    static func searchPath(groupTitle: String, pageTitle: String, sectionTitles: [String]) -> String {
        var deduplicated = [String]()
        for title in sectionTitles where !deduplicated.contains(title) {
            deduplicated.append(title)
        }
        var components = [groupTitle, pageTitle]
        components.append(contentsOf: deduplicated.prefix(2))
        if deduplicated.count > 2 {
            components.append("…")
        }
        return components.joined(separator: " › ")
    }
}
