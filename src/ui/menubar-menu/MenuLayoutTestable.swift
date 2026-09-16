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

    /// The app group closes the menu without a heading, like every macOS app menu.
    var hasHeader: Bool { self != .app }

    /// Groups visible after the update; everything else waits until the user turns it on.
    var visibleByDefault: Bool { [.switcher, .windows, .app].contains(self) }

    /// `Settings…` and `Quit` live here, so hiding it would leave no way back.
    var canBeHidden: Bool { self != .app }
}

struct MenuEntrySpec: Equatable {
    let id: String
    let group: MenuGroup
}

enum MenuLayoutItem: Equatable {
    case header(MenuGroup)
    case separator
    case entry(String)
}

enum MenuLayout {
    /// Visible groups in order, a separator between them, a heading on top of each where supported. An
    /// empty group leaves no heading and no separator behind.
    static func build(_ entries: [MenuEntrySpec], headersSupported: Bool, isVisible: (MenuEntrySpec) -> Bool) -> [MenuLayoutItem] {
        var items = [MenuLayoutItem]()
        for group in MenuGroup.allCases {
            let visible = entries.filter { $0.group == group && isVisible($0) }
            guard !visible.isEmpty else { continue }
            appendGroup(group, visible, headersSupported, &items)
        }
        return items
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
