import Cocoa
import ShortcutRecorder

/// Story 16, stage 3: every action shortcut in one list. A shortcut keeps its recorder where its object is
/// defined (layouts, spaces, apps, profiles, keep awake); only menu actions without such a page are
/// recorded here. One recorder per shortcut, so the two places can never disagree.
class ShortcutOverviewTab {
    static let sectionId = "shortcuts"
    private static let container = RebuildableSettingsView(sectionId: sectionId)
    private static var filter = ShortcutOverviewFilter.all
    private static var isStale = true
    private static var refreshScheduled = false

    static func initTab() -> NSView {
        rebuild()
        return container
    }

    /// Called when the page is shown; rebuilds only when something changed meanwhile.
    static func pageShown() {
        guard isStale else { return }
        rebuild()
    }

    /// Called for every change of an action shortcut, possibly several in a row.
    static func shortcutsChanged() {
        isStale = true
        guard !refreshScheduled, SettingsWindow.shared?.isShowingSection(sectionId) == true else { return }
        refreshScheduled = true
        DispatchQueue.main.async {
            refreshScheduled = false
            rebuild()
        }
    }

    private static func rebuild() {
        isStale = false
        let rows = ShortcutCatalog.rows()
        container.rebuild { views(rows) }
    }

    private static func views(_ rows: [ShortcutOverviewRow]) -> [NSView] {
        var views: [NSView] = [filterTable(rows)]
        let conflicts = ShortcutOverview.conflicts(rows)
        if filter == .all, !conflicts.isEmpty {
            views.append(table(NSLocalizedString("Needs attention", comment: ""), conflicts, recorders: false))
        }
        let visible = ShortcutOverview.visible(rows, filter)
        if visible.isEmpty {
            views.append(emptyTable())
        }
        ShortcutOverview.grouped(visible).forEach { views.append(table($0.0, $0.1, recorders: true)) }
        return views
    }

    private static func filterTable(_ rows: [ShortcutOverviewRow]) -> TableGroupView {
        let labels = [NSLocalizedString("All", comment: ""), NSLocalizedString("Assigned", comment: ""),
                      String(format: NSLocalizedString("Conflicts (%d)", comment: ""), ShortcutOverview.conflicts(rows).count)]
        let control = NSSegmentedControl(labels: labels, trackingMode: .selectOne, target: nil, action: nil)
        control.selectedSegment = filter.rawValue
        control.onAction = { sender in
            filter = ShortcutOverviewFilter(rawValue: (sender as? NSSegmentedControl)?.selectedSegment ?? 0) ?? .all
            rebuild()
        }
        let table = TableGroupView(width: SettingsWindow.contentWidth)
        table.addRow(TableGroupView.Row(leftTitle: NSLocalizedString("Show", comment: ""), rightViews: [control]))
        return table
    }

    private static func emptyTable() -> TableGroupView {
        let table = TableGroupView(width: SettingsWindow.contentWidth)
        let text = filter == .conflicts ? NSLocalizedString("No conflicts.", comment: "") : NSLocalizedString("No shortcuts assigned yet.", comment: "")
        table.addRow(TableGroupView.Row(leftTitle: text, rightViews: []))
        return table
    }

    private static func table(_ title: String, _ rows: [ShortcutOverviewRow], recorders: Bool) -> TableGroupView {
        let table = TableGroupView(title: title, width: SettingsWindow.contentWidth)
        rows.forEach { table.addRow(row($0, recorders: recorders)) }
        return table
    }

    private static func row(_ row: ShortcutOverviewRow, recorders: Bool) -> TableGroupView.Row {
        var views = [NSView]()
        if recorders, row.ownerSectionId == nil {
            views.append(LabelAndControl.makeLabelWithRecorder(row.title, row.key, Preferences.shortcut(row.key))[1])
        } else {
            views.append(shortcutLabel(row.key))
        }
        if let owner = row.ownerSectionId {
            let show = NSButton(title: NSLocalizedString("Show", comment: ""), target: nil, action: nil)
            show.onAction = { _ in reveal(owner, row) }
            views.append(show)
        }
        return TableGroupView.Row(leftTitle: row.title, subTitle: statusText(row.status), rightViews: views)
    }

    /// Opens the owning page and flashes the shortcut's recorder row. Profiles shows only its
    /// selected profile at a time (picked from a popup, not by name), so a profile shortcut must
    /// first select its slot before the generic "Shortcut" row can be found and revealed.
    private static func reveal(_ owner: String, _ row: ShortcutOverviewRow) {
        if let index = row.profileIndex {
            ProfilesTab.select(index)
            SettingsWindow.shared?.reveal(sectionId: owner, rowTitle: NSLocalizedString("Shortcut", comment: ""))
        } else {
            SettingsWindow.shared?.reveal(sectionId: owner, rowTitle: row.title)
        }
    }

    private static func shortcutLabel(_ key: String) -> NSTextField {
        let text = ControlsTab.shortcuts[key].map { symbolic($0.shortcut) } ?? ""
        let label = NSTextField(labelWithString: text.isEmpty ? NSLocalizedString("None", comment: "") : text)
        label.textColor = text.isEmpty ? .tertiaryLabelColor : .labelColor
        return label
    }

    /// The same `⌃⌥⇧⌘D` notation the recorders use; spelled-out names widened the window.
    private static func symbolic(_ shortcut: Shortcut) -> String {
        let modifiers = SymbolicModifierFlagsTransformer.shared.transformedValue(NSNumber(value: shortcut.modifierFlags.rawValue)) ?? ""
        let key = shortcut.keyCode == .none ? "" : (SymbolicKeyCodeTransformer.shared.transformedValue(NSNumber(value: shortcut.keyCode.rawValue)) ?? "").uppercased()
        return modifiers + key
    }

    private static func statusText(_ status: ShortcutStatus) -> String? {
        switch status {
            case .unassigned, .ok: return nil
            case .replacesMacosShortcut: return NSLocalizedString("Replaces a macOS shortcut while assigned.", comment: "")
            case .duplicate(let other): return String(format: NSLocalizedString("⚠︎ Also used by %@.", comment: ""), other)
            case .reservedByMacos: return NSLocalizedString("⚠︎ Reserved by macOS; it will not work.", comment: "")
            case .usedByGameOverlay: return NSLocalizedString("⚠︎ Used by the macOS Game Overlay.", comment: "")
        }
    }
}

/// Which action shortcuts exist, what they are called, and where their recorder lives.
enum ShortcutCatalog {
    private struct Entry {
        let key: String
        let title: String
        let group: String
        let owner: String?
        let profileIndex: Int?

        init(key: String, title: String, group: String, owner: String?, profileIndex: Int? = nil) {
            self.key = key
            self.title = title
            self.group = group
            self.owner = owner
            self.profileIndex = profileIndex
        }
    }

    static func rows() -> [ShortcutOverviewRow] {
        let entries = catalog()
        let titles = Dictionary(entries.map { ($0.key, $0.title) }, uniquingKeysWith: { first, _ in first })
        let groups = orderedGroups(entries)
        return entries.map { entry in
            ShortcutOverviewRow(key: entry.key, title: entry.title, groupOrder: groups.firstIndex(of: entry.group) ?? 0,
                                groupTitle: entry.group, ownerSectionId: entry.owner, profileIndex: entry.profileIndex,
                                status: status(entry.key, titles))
        }
    }

    private static func orderedGroups(_ entries: [Entry]) -> [String] {
        var groups = [String]()
        entries.forEach { if !groups.contains($0.group) { groups.append($0.group) } }
        return groups
    }

    private static func catalog() -> [Entry] {
        var entries = [Entry]()
        let layouts = NSLocalizedString("Window Layouts", comment: "")
        WindowLayoutAction.allCases.forEach { entries.append(Entry(key: $0.shortcutPreferenceKey, title: $0.localizedTitle, group: layouts, owner: "window-layouts")) }
        DisplayMoveAction.allCases.forEach { entries.append(Entry(key: $0.shortcutPreferenceKey, title: $0.localizedTitle, group: layouts, owner: "window-layouts")) }
        entries.append(Entry(key: ShortcutCluesController.shortcutPreferenceKey, title: NSLocalizedString("Shortcut Clues", comment: ""), group: layouts, owner: "window-layouts"))
        let spaces = NSLocalizedString("Spaces", comment: "")
        SpaceAction.all.forEach { entries.append(Entry(key: $0.shortcutPreferenceKey, title: $0.localizedTitle, group: spaces, owner: "spaces")) }
        entries.append(contentsOf: appEntries())
        entries.append(contentsOf: profileEntries())
        entries.append(contentsOf: systemActionEntries())
        return entries.filter { ControlsTab.isGlobalActionShortcut($0.key) && ShortcutOverview.isActionShortcutKey($0.key) }
    }

    private static func appEntries() -> [Entry] {
        let group = NSLocalizedString("Apps & URLs", comment: "")
        let apps = (0..<Preferences.maxLaunchAppCount).filter { SlotList.isOccupied(Preferences.launchAppBundleIdentifier($0)) }.map { index -> Entry in
            let value = Preferences.launchAppBundleIdentifier(index)
            let title = NSWorkspace.shared.urlForApplication(withBundleIdentifier: value).map(DefaultBrowser.displayName) ?? value
            return Entry(key: LaunchAppAction.shortcutPreferenceKey(index), title: title, group: group, owner: "apps-urls")
        }
        let urls = (0..<Preferences.maxOpenUrlCount).filter { SlotList.isOccupied(Preferences.openUrlValue($0)) }.map {
            Entry(key: OpenUrlAction.shortcutPreferenceKey($0), title: Preferences.openUrlValue($0), group: group, owner: "apps-urls")
        }
        return apps + urls
    }

    private static func profileEntries() -> [Entry] {
        let group = NSLocalizedString("Profiles", comment: "")
        return (0..<Preferences.maxProfileCount).filter { ProfileStore.profile($0) != nil }.map { index in
            let name = CachedUserDefaults.string(ProfileStore.nameKey(index))
            let title = name.isEmpty ? String(format: NSLocalizedString("Profile %d", comment: ""), index + 1) : name
            return Entry(key: ProfileStore.shortcutPreferenceKey(index), title: title, group: group, owner: "profiles", profileIndex: index)
        }
    }

    private static func systemActionEntries() -> [Entry] {
        SystemActions.all.map { spec in
            let isKeepAwake = KeepAwakeTab.actions.contains(spec.action)
            let group = isKeepAwake ? NSLocalizedString("Keep Awake", comment: "") : MenubarMenu.groupTitle(spec.group)
            return Entry(key: spec.action.shortcutPreferenceKey, title: spec.title, group: group, owner: isKeepAwake ? "keep-awake" : nil)
        }
    }

    private static func status(_ key: String, _ titles: [String: String]) -> ShortcutStatus {
        guard let shortcut = ControlsTab.shortcuts[key]?.shortcut, shortcut.keyCode != .none else { return .unassigned }
        let new = CustomRecorderControlTestable.newCombinationsFromCandidate(key, shortcut)
        let old = CustomRecorderControlTestable.oldCombinationsExcludingTargetOfCandidate(key)
        if let other = CustomRecorderControlTestable.isAlreadyUsedByAnotherShortcut(new, old) {
            return .duplicate(otherTitle: titles[other] ?? ControlsTab.shortcutControls[other]?.1 ?? other)
        }
        if CustomRecorderControlTestable.isReservedByMacos(new) != nil { return .reservedByMacos }
        if CustomRecorderControlTestable.isUsedByGameOverlay(new) != nil { return .usedByGameOverlay }
        return NativeSystemShortcuts.replacesSystemShortcut(shortcut) ? .replacesMacosShortcut : .ok
    }
}
