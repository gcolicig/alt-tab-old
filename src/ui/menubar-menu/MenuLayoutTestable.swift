import Foundation

/// Groups of the menubar menu, in display order. The groups follow what the entries do (story 15); a new
/// entry joins an existing group unless none fits.
enum MenuGroup: String, CaseIterable {
    case switcher
    case windows
    case apps
    case tools
    case notifications
    case system
    case toggles
    case defaults
    case app

    /// The app group closes the menu without a heading, like every macOS app menu. A group shown as a
    /// submenu is named by its own entry instead.
    var hasHeader: Bool { self != .app && !isSubmenu }

    /// Decided 2026-09-16: these groups each become a submenu, and all of them sit together under one
    /// `Other Tools` entry.
    var isSubmenu: Bool { [.tools, .toggles].contains(self) }

    /// Groups visible after the update; everything else waits until the user turns it on.
    var visibleByDefault: Bool { [.switcher, .windows, .app].contains(self) }

    /// `Settings…` and `Quit` live in the app group, so hiding it would leave no way back. Tools is always
    /// shown, as decided on 2026-09-16.
    var canBeHidden: Bool { ![.app, .tools].contains(self) }
}

struct MenuEntrySpec: Equatable {
    let id: String
    let group: MenuGroup
}

enum MenuLayoutItem: Equatable {
    case header(MenuGroup)
    case separator
    case entry(String)
    case otherTools([MenuGroupEntries])
}

struct MenuGroupEntries: Equatable {
    let group: MenuGroup
    let ids: [String]
}

enum MenuLayout {
    /// Visible groups in order, a separator between them, a heading on top of each where supported. An
    /// empty group leaves no heading and no separator behind.
    static func build(_ entries: [MenuEntrySpec], headersSupported: Bool, isVisible: (MenuEntrySpec) -> Bool) -> [MenuLayoutItem] {
        var items = [MenuLayoutItem]()
        let nested = MenuGroup.allCases.filter(\.isSubmenu).compactMap { group -> MenuGroupEntries? in
            let ids = entries.filter { $0.group == group && isVisible($0) }.map(\.id)
            return ids.isEmpty ? nil : MenuGroupEntries(group: group, ids: ids)
        }
        for group in MenuGroup.allCases {
            if group.isSubmenu {
                appendOtherTools(group, nested, &items)
                continue
            }
            let visible = entries.filter { $0.group == group && isVisible($0) }
            guard !visible.isEmpty else { continue }
            appendGroup(group, visible, headersSupported, &items)
        }
        return items
    }

    /// Placed where the first nested group would have been, once.
    private static func appendOtherTools(_ group: MenuGroup, _ nested: [MenuGroupEntries], _ items: inout [MenuLayoutItem]) {
        guard group == nested.first?.group else { return }
        if !items.isEmpty { items.append(.separator) }
        items.append(.otherTools(nested))
    }

    private static func appendGroup(_ group: MenuGroup, _ entries: [MenuEntrySpec], _ headersSupported: Bool, _ items: inout [MenuLayoutItem]) {
        if !items.isEmpty { items.append(.separator) }
        if headersSupported && group.hasHeader { items.append(.header(group)) }
        items.append(contentsOf: entries.map { .entry($0.id) })
    }

    /// Configurable menu entries that are not `SystemAction`s. Each needs a registered default, because
    /// the settings switches read their preference unconditionally.
    static let showEntryId = "app.show"
    static let defaultBrowserEntryId = "defaults.browser"
    static let nonActionEntryIds = [showEntryId, defaultBrowserEntryId]

    static func groupPreferenceKey(_ group: MenuGroup) -> String {
        "menuGroupVisible." + group.rawValue
    }

    static func entryPreferenceKey(_ id: String) -> String {
        "menuEntryVisible." + id
    }
}
