import Cocoa

/// Story 15. Builds the menubar menu once from `MenuLayout`; `menuNeedsUpdate` refreshes checkmarks,
/// titles and availability on open without any AX work or process start (MG-04).
final class MenubarMenu: NSObject, NSMenuDelegate {
    static let shared = MenubarMenu()
    private var entries = [String: MenubarEntry]()
    private var items = [String: NSMenuItem]()

    func build() -> NSMenu {
        SubmenuBuilder.releaseAll()
        entries = Dictionary(uniqueKeysWithValues: Self.allEntries().map { ($0.id, $0) })
        items.removeAll()
        let menu = NSMenu()
        menu.title = App.name // perf: prevent going through expensive code-path within appkit
        menu.autoenablesItems = false
        menu.delegate = self
        let specs = Self.allEntries().map { MenuEntrySpec(id: $0.id, group: $0.group) }
        layout(specs).forEach { menu.addItem(makeItem($0)) }
        return menu
    }

    private func layout(_ specs: [MenuEntrySpec]) -> [MenuLayoutItem] {
        guard #available(macOS 14.0, *) else { return MenuLayout.build(specs, headersSupported: false) }
        return MenuLayout.build(specs, headersSupported: true)
    }

    private func makeItem(_ layoutItem: MenuLayoutItem) -> NSMenuItem {
        switch layoutItem {
            case .separator: return .separator()
            case .header(let group): return header(group)
            case .entry(let id): return entryItem(entries[id]!)
            case .other(let groups): return otherItem(groups)
        }
    }

    /// Decided 2026-09-16: inside `Other…` each group is a headed section, like the groups of the main
    /// menu, not a further submenu. Its items stay in `items`, so the same refresh keeps checkmarks
    /// and availability current when the submenu opens.
    private func otherItem(_ groups: [MenuGroupEntries]) -> NSMenuItem {
        let item = NSMenuItem(title: NSLocalizedString("Other…", comment: ""), action: nil, keyEquivalent: "")
        if #available(macOS 26.0, *) {
            item.image = NSImage(systemSymbolName: "square.grid.2x2", accessibilityDescription: nil)
        }
        let submenu = NSMenu(title: item.title)
        submenu.autoenablesItems = false
        submenu.delegate = self
        groups.enumerated().forEach { index, group in
            if index > 0 { submenu.addItem(.separator()) }
            addSection(group, to: submenu)
        }
        item.submenu = submenu
        return item
    }

    private func addSection(_ group: MenuGroupEntries, to menu: NSMenu) {
        if #available(macOS 14.0, *) {
            menu.addItem(NSMenuItem.sectionHeader(title: Self.groupTitle(group.group)))
        }
        group.ids.compactMap { entries[$0] }.forEach { menu.addItem(entryItem($0)) }
    }

    private func header(_ group: MenuGroup) -> NSMenuItem {
        guard #available(macOS 14.0, *) else { return .separator() }
        return NSMenuItem.sectionHeader(title: Self.groupTitle(group))
    }

    private func entryItem(_ entry: MenubarEntry) -> NSMenuItem {
        let item = NSMenuItem(title: entry.title(), action: #selector(invoke(_:)), keyEquivalent: entry.keyEquivalent)
        item.target = self
        item.representedObject = entry.id
        if #available(macOS 26.0, *), let symbol = entry.symbol {
            item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        }
        if let submenu = entry.submenu?() {
            item.submenu = submenu
            item.action = nil
        }
        items[entry.id] = item
        return item
    }

    @objc private func invoke(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        entries[id]?.run()
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        items.forEach { id, item in
            guard let entry = entries[id] else { return }
            item.title = entry.title()
            item.isEnabled = entry.isEnabled()
            item.state = entry.isOn?() == true ? .on : .off
            item.toolTip = entry.disabledReason()
        }
    }

    static func groupTitle(_ group: MenuGroup) -> String {
        switch group {
            case .switcher: return NSLocalizedString("Switcher", comment: "")
            case .windows: return NSLocalizedString("Windows", comment: "")
            case .apps: return NSLocalizedString("Apps", comment: "")
            case .tools: return NSLocalizedString("Tools", comment: "")
            case .notifications: return NSLocalizedString("Notifications", comment: "")
            case .system: return NSLocalizedString("System", comment: "")
            case .toggles: return NSLocalizedString("Toggles", comment: "")
            case .defaults: return NSLocalizedString("Defaults", comment: "")
            case .settings, .app: return App.name
        }
    }

    // MARK: entries

    static func allEntries() -> [MenubarEntry] {
        [settingsEntry, showEntry] + SystemActions.all.filter { !keepAwakeActions.contains($0.action) }.map(MenubarEntry.init)
            + [keepAwakeEntry, defaultBrowserEntry] + appEntries
    }

    private static let keepAwakeActions: Set<SystemAction> = [.keepAwakeToggle, .keepAwakeStop, .keepAwakeIndefinitely, .keepAwake15Minutes,
                                                              .keepAwake1Hour, .keepAwake2Hours, .keepAwake5Hours]

    private static let showEntry = MenubarEntry(id: MenuLayout.showEntryId, group: .switcher, title: { NSLocalizedString("Show", comment: "Menubar option") },
        symbol: "eye") { App.showUiFromShortcut0() }

    private static let keepAwakeEntry = MenubarEntry(id: SystemAction.keepAwakeToggle.rawValue, group: .toggles, title: KeepAwake.menuTitle,
        symbol: "cup.and.saucer", isOn: { KeepAwake.isActive }, submenu: { SubmenuBuilder.keepAwake() }) {}

    private static let defaultBrowserEntry = MenubarEntry(id: MenuLayout.defaultBrowserEntryId, group: .defaults, title: { NSLocalizedString("Default Browser", comment: "") },
        symbol: "globe", submenu: { SubmenuBuilder.defaultBrowser() }) {}

    private static let settingsEntry = MenubarEntry(id: "app.settings", group: .settings, title: { NSLocalizedString("Settings…", comment: "Menubar option") },
        symbol: "gear", keyEquivalent: ",") { App.showSettingsWindow() }

    private static let appEntries: [MenubarEntry] = [
        MenubarEntry(id: "app.about", group: .app, title: { String(format: NSLocalizedString("About %@", comment: "Menubar option. %@ is AltTab"), App.name) },
            symbol: "info.circle") { App.showAboutWindow() },
        MenubarEntry(id: "app.permissions", group: .app, title: { NSLocalizedString("Check permissions…", comment: "Menubar option") },
            symbol: "hand.raised") { App.showPermissionsWindow() },
        MenubarEntry(id: "app.debug", group: .app, title: { NSLocalizedString("Debug", comment: "Menubar option") }, symbol: "wrench.and.screwdriver",
            submenu: { SubmenuBuilder.debug() }) {},
        MenubarEntry(id: "app.quit", group: .app, title: { String(format: NSLocalizedString("Quit %@", comment: "Menubar option. %@ is AltTab"), App.name) },
            symbol: nil, keyEquivalent: "q") { NSApp.terminate(nil) },
    ]
}

struct MenubarEntry {
    let id: String
    let group: MenuGroup
    let title: () -> String
    let symbol: String?
    var keyEquivalent = ""
    var isOn: (() -> Bool)?
    var availability: () -> ActionAvailability = { .available }
    var submenu: (() -> NSMenu)?
    let run: () -> Void

    init(id: String, group: MenuGroup, title: @escaping () -> String, symbol: String?, keyEquivalent: String = "",
         isOn: (() -> Bool)? = nil, submenu: (() -> NSMenu)? = nil, run: @escaping () -> Void) {
        self.id = id
        self.group = group
        self.title = title
        self.symbol = symbol
        self.keyEquivalent = keyEquivalent
        self.isOn = isOn
        self.submenu = submenu
        self.run = run
    }

    init(_ spec: SystemActionSpec) {
        self.init(id: spec.action.rawValue, group: spec.group, title: { spec.title }, symbol: spec.symbol, isOn: spec.isOn) {
            Actions.perform(.system(spec.action))
        }
        availability = spec.availability
    }

    func isEnabled() -> Bool {
        availability().isAvailable
    }

    func disabledReason() -> String? {
        guard case .unavailable(let reason) = availability() else { return nil }
        return reason
    }
}

/// Submenus rebuild their items each time they open, so their content is never stale.
final class SubmenuBuilder: NSObject, NSMenuDelegate {
    private let fill: (NSMenu) -> Void
    private let target = ClosureMenuTarget()
    private static var retained = [SubmenuBuilder]()

    private init(_ fill: @escaping (NSMenu) -> Void) {
        self.fill = fill
    }

    private static func make(_ fill: @escaping (NSMenu, ClosureMenuTarget) -> Void) -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false
        var builder: SubmenuBuilder!
        builder = SubmenuBuilder { fill($0, builder.target) }
        retained.append(builder)
        menu.delegate = builder
        return menu
    }

    static func releaseAll() {
        retained.removeAll()
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        target.reset()
        fill(menu)
    }

    static func keepAwake() -> NSMenu {
        make { menu, target in
            let active = KeepAwake.isActive
            menu.addItem(target.item(active ? NSLocalizedString("Turn Off", comment: "") : NSLocalizedString("Turn On", comment: "")) { KeepAwake.toggle() })
            menu.addItem(.separator())
            KeepAwakeDuration.allCases.forEach { duration in
                menu.addItem(target.item(durationTitle(duration)) { KeepAwake.start(duration) })
            }
            menu.addItem(target.item(NSLocalizedString("Until…", comment: "")) { KeepAwake.askUntil() })
            if active, KeepAwake.session?.endsAt != nil {
                menu.addItem(target.item(NSLocalizedString("Extend by 1 Hour", comment: "")) { KeepAwake.extend(by: 3600) })
            }
            menu.addItem(.separator())
            let display = target.item(NSLocalizedString("Keep Display Awake", comment: "")) {
                Preferences.set("keepAwakeDisplay", Preferences.keepAwakeDisplay ? "false" : "true")
            }
            display.state = Preferences.keepAwakeDisplay ? .on : .off
            menu.addItem(display)
        }
    }

    static func durationTitle(_ duration: KeepAwakeDuration) -> String {
        switch duration {
            case .indefinitely: return NSLocalizedString("Indefinitely", comment: "")
            case .minutes15: return NSLocalizedString("15 Minutes", comment: "")
            case .hour1: return NSLocalizedString("1 Hour", comment: "")
            case .hours2: return NSLocalizedString("2 Hours", comment: "")
            case .hours5: return NSLocalizedString("5 Hours", comment: "")
        }
    }

    static func defaultBrowser() -> NSMenu {
        make { menu, target in
            let browsers = DefaultBrowser.installed()
            let names = browsers.map(DefaultBrowser.displayName)
            let current = DefaultBrowser.current()
            for (index, url) in browsers.enumerated() {
                let item = target.item(names[index]) { DefaultBrowser.set(url) }
                item.image = icon(url)
                item.state = url.standardizedFileURL == current?.standardizedFileURL ? .on : .off
                if names.filter({ $0 == names[index] }).count > 1 { item.toolTip = DebugRedaction.homeRedacted(url.path) }
                menu.addItem(item)
            }
            if browsers.isEmpty { menu.addItem(withTitle: NSLocalizedString("No browsers found", comment: ""), action: nil, keyEquivalent: "") }
        }
    }

    private static func icon(_ url: URL) -> NSImage {
        let image = NSWorkspace.shared.icon(forFile: url.path)
        image.size = NSSize(width: 16, height: 16)
        return image
    }

    static func debug() -> NSMenu {
        make { menu, target in
            menu.addItem(target.item(NSLocalizedString("Copy Debug Info", comment: ""), symbol: "doc.on.doc") { DebugTools.copyDebugInfo() })
            menu.addItem(target.item(NSLocalizedString("Copy Accessibility Tree", comment: ""), symbol: "doc.on.doc") { DebugTools.copyAccessibilityTree() })
            menu.addItem(target.item(NSLocalizedString("Reset Permissions…", comment: ""), symbol: "arrow.uturn.backward") { DebugTools.resetPermissions() })
            menu.addItem(.separator())
            menu.addItem(target.item(NSLocalizedString("Debug Tools…", comment: ""), symbol: "scope") { App.showDebugWindow() })
        }
    }
}

final class ClosureMenuTarget: NSObject {
    private var actions = [() -> Void]()

    func reset() {
        actions.removeAll()
    }

    func item(_ title: String, symbol: String? = nil, _ action: @escaping () -> Void) -> NSMenuItem {
        actions.append(action)
        let item = NSMenuItem(title: title, action: #selector(invoke(_:)), keyEquivalent: "")
        item.target = self
        item.tag = actions.count - 1
        if #available(macOS 26.0, *), let symbol {
            item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        }
        return item
    }

    @objc private func invoke(_ sender: NSMenuItem) {
        guard actions.indices.contains(sender.tag) else { return }
        actions[sender.tag]()
    }
}
