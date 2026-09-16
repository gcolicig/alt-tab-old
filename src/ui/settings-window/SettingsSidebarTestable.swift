import Foundation

/// Story 16, stage 1: the sidebar groups and which page is shown.
enum SettingsSidebarGroup: String, CaseIterable {
    case app
    case switcher
    case windows
    case triggers
    case devices
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
        (.triggers, ["hyperkey", "leader", "flick-ring"]),
        (.devices, ["pointer-scroll"]),
        (.actions, ["menubar-menu", "system-actions", "keep-awake", "apps-urls"]),
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

    static func displayed(all: [String], matching: [String], selected: String?, searching: Bool) -> [String] {
        guard searching else { return selected.map { [$0] } ?? [] }
        return all.filter { matching.contains($0) }
    }
}
