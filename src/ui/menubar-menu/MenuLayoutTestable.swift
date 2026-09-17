import Foundation

/// Groups of the menubar menu, in display order. The groups follow what the entries do (story 15); a new
/// entry joins an existing group unless none fits.
enum MenuGroup: String, CaseIterable {
    case settings
    case switcher
    case windows
    case apps
    case tools
    case notifications
    case system
    case toggles
    case defaults
    case app

    /// `settings` is kept for a menu that opens with `Settings…` on its own (decided 2026-09-16); since
    /// 2026-09-17 the entry sits in the app group instead, so the group stays empty. Neither needs a heading.
    var hasHeader: Bool { ![.settings, .app].contains(self) }

    /// Decided 2026-09-16: every group except the switcher, the window actions and the app block becomes a
    /// headed section of one `Other…` submenu. Nothing is hidden any more, so nothing needs switching.
    var isInOther: Bool { ![.settings, .switcher, .windows, .app].contains(self) }
}

struct MenuEntrySpec: Equatable {
    let id: String
    let group: MenuGroup
}

enum MenuLayoutItem: Equatable {
    case header(MenuGroup)
    case separator
    case entry(String)
    case other([MenuGroupEntries])
}

struct MenuGroupEntries: Equatable {
    let group: MenuGroup
    let ids: [String]
}

enum MenuLayout {
    static let showEntryId = "app.show"
    static let defaultBrowserEntryId = "defaults.browser"
    /// Written by the visibility switches that existed until 2026-09-16; removed once at launch.
    static let retiredPreferencePrefixes = ["menuGroupVisible.", "menuEntryVisible."]

    /// Groups in order, a separator between them, a heading on top of each where supported. The groups
    /// that belong to `Other…` appear once, together, where the first of them would have been. An empty
    /// group leaves no heading and no separator behind.
    static func build(_ entries: [MenuEntrySpec], headersSupported: Bool) -> [MenuLayoutItem] {
        var items = [MenuLayoutItem]()
        let other = otherGroups(entries)
        for group in MenuGroup.allCases {
            if group.isInOther {
                appendOther(group, other, &items)
                continue
            }
            let ids = entries.filter { $0.group == group }.map(\.id)
            guard !ids.isEmpty else { continue }
            appendGroup(group, ids, headersSupported, &items)
        }
        return items
    }

    private static func otherGroups(_ entries: [MenuEntrySpec]) -> [MenuGroupEntries] {
        MenuGroup.allCases.filter(\.isInOther).compactMap { group in
            let ids = entries.filter { $0.group == group }.map(\.id)
            return ids.isEmpty ? nil : MenuGroupEntries(group: group, ids: ids)
        }
    }

    private static func appendOther(_ group: MenuGroup, _ other: [MenuGroupEntries], _ items: inout [MenuLayoutItem]) {
        guard group == other.first?.group else { return }
        if !items.isEmpty { items.append(.separator) }
        items.append(.other(other))
    }

    private static func appendGroup(_ group: MenuGroup, _ ids: [String], _ headersSupported: Bool, _ items: inout [MenuLayoutItem]) {
        if !items.isEmpty { items.append(.separator) }
        if headersSupported && group.hasHeader { items.append(.header(group)) }
        items.append(contentsOf: ids.map { .entry($0) })
    }

    static func isRetiredPreference(_ key: String) -> Bool {
        retiredPreferencePrefixes.contains { key.hasPrefix($0) }
    }
}
