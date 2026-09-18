import Cocoa

/// Project profiles: name, apps, optional layout, optional bound space, optional shortcut. Activation
/// switches the bound space and filters the switcher to the profile's apps. Nothing is started, quit,
/// hidden, or moved.
///
/// Story 16, stage 2: one profile at a time, picked from the filled slots. A new profile takes the first
/// free slot; deleting empties its slot without moving the others, so shortcuts and bindings stay put.
class ProfilesTab {
    private static let container = RebuildableSettingsView()
    private static var selected: Int?
    private static var picker: NSPopUpButton?
    private static var bindingLabel: NSTextField?

    static func initTab() -> NSView {
        refresh()
        return container
    }

    private static func refresh() {
        let slots = occupiedSlots()
        if selected.map({ !slots.contains($0) }) ?? true { selected = slots.first }
        container.rebuild(makeViews)
    }

    private static func occupiedSlots() -> [Int] {
        (0..<Preferences.maxProfileCount).filter { ProfileStore.profile($0) != nil }
    }

    private static func freeSlot() -> Int? {
        (0..<Preferences.maxProfileCount).first { ProfileStore.profile($0) == nil }
    }

    private static func makeViews() -> [NSView] {
        guard let index = selected else { return [pickerTable()] }
        return [pickerTable(), detailsTable(index)]
    }

    // MARK: picker

    private static func pickerTable() -> TableGroupView {
        let table = TableGroupView(width: SettingsWindow.contentWidth)
        let slots = occupiedSlots()
        guard !slots.isEmpty else {
            table.addRow(TableGroupView.Row(leftTitle: NSLocalizedString("No profiles yet.", comment: ""),
                subTitle: NSLocalizedString("A profile shows only its apps in the switcher and can switch to its space.", comment: ""),
                rightViews: [newButton()]))
            return table
        }
        table.addRow(TableGroupView.Row(leftTitle: NSLocalizedString("Profile", comment: ""), rightViews: [profilePicker(slots), newButton(), deleteButton()]))
        return table
    }

    private static func profilePicker(_ slots: [Int]) -> NSPopUpButton {
        let popup = PopupButtonLikeSystemSettings()
        slots.forEach { slot in
            popup.addItem(withTitle: title(slot))
            popup.lastItem?.tag = slot
        }
        popup.selectItem(withTag: selected ?? -1)
        popup.onAction = { control in
            selected = (control as? NSPopUpButton)?.selectedItem?.tag
            refresh()
        }
        picker = popup
        return popup
    }

    private static func title(_ slot: Int) -> String {
        let name = CachedUserDefaults.string(ProfileStore.nameKey(slot)).trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? String(format: NSLocalizedString("Profile %d", comment: ""), slot + 1) : name
    }

    private static func newButton() -> NSButton {
        let button = NSButton(title: NSLocalizedString("New", comment: ""), target: nil, action: nil)
        button.onAction = { _ in createProfile() }
        if freeSlot() == nil {
            button.isEnabled = false
            button.toolTip = String(format: NSLocalizedString("All %d profiles are in use. Delete one first.", comment: ""), Preferences.maxProfileCount)
        }
        return button
    }

    private static func deleteButton() -> NSButton {
        let button = NSButton(title: NSLocalizedString("Delete…", comment: ""), target: nil, action: nil)
        button.onAction = { _ in deleteSelectedProfile() }
        return button
    }

    /// A new profile gets a name right away, so its slot counts as filled.
    private static func createProfile() {
        guard let slot = freeSlot() else { return }
        Preferences.set(ProfileStore.nameKey(slot), String(format: NSLocalizedString("Profile %d", comment: ""), slot + 1))
        selected = slot
        refresh()
    }

    private static func deleteSelectedProfile() {
        guard let slot = selected else { return }
        let alert = NSAlert()
        alert.messageText = String(format: NSLocalizedString("Delete %@?", comment: ""), title(slot))
        alert.informativeText = NSLocalizedString("Its apps, layout, bound space, and shortcut are removed too.", comment: "")
        alert.addButton(withTitle: NSLocalizedString("Cancel", comment: ""))
        alert.addButton(withTitle: NSLocalizedString("Delete", comment: ""))
        guard alert.runModal() == .alertSecondButtonReturn else { return }
        [ProfileStore.nameKey(slot), ProfileStore.appsKey(slot), ProfileStore.layoutKey(slot), ProfileStore.spaceUuidKey(slot)].forEach {
            Preferences.set($0, "")
        }
        Preferences.setShortcut(ProfileStore.shortcutPreferenceKey(slot), nil)
        selected = nil
        refresh()
    }

    // MARK: details

    private static func detailsTable(_ index: Int) -> TableGroupView {
        let table = TableGroupView(width: SettingsWindow.contentWidth)
        let name = LabelAndControl.makeTextArea(24, 1, NSLocalizedString("Name", comment: ""), ProfileStore.nameKey(index),
                                                extraAction: { _ in picker?.selectedItem?.title = title(index) })
        table.addRow(TableGroupView.Row(leftTitle: NSLocalizedString("Name", comment: ""), rightViews: name))
        appRows(index).forEach { table.addRow($0) }
        table.addRow(TableGroupView.Row(leftTitle: NSLocalizedString("Layout", comment: ""), rightViews: [makeLayoutPopup(index)]))
        table.addRow(TableGroupView.Row(leftTitle: NSLocalizedString("Bound space", comment: ""),
                                        subTitle: NSLocalizedString("A lost binding is shown, never repointed.", comment: ""),
                                        rightViews: makeBindingViews(index)))
        let key = ProfileStore.shortcutPreferenceKey(index)
        let recorder = LabelAndControl.makeLabelWithRecorder(NSLocalizedString("Shortcut", comment: ""), key, Preferences.shortcut(key))
        table.addRow(TableGroupView.Row(leftTitle: NSLocalizedString("Shortcut", comment: ""), rightViews: [recorder[1]]))
        return table
    }

    private static func appRows(_ index: Int) -> [TableGroupView.Row] {
        let stored = CachedUserDefaults.string(ProfileStore.appsKey(index))
        let choose = NSButton(title: NSLocalizedString("Choose…", comment: ""), target: nil, action: nil)
        choose.onAction = { _ in chooseApps(index) }
        let header = TableGroupView.Row(leftTitle: NSLocalizedString("Apps", comment: ""),
            subTitle: NSLocalizedString("Only these apps show while the profile is active.", comment: ""), rightViews: [choose])
        return [header] + ProfileAppsFormat.parse(stored).map { appRow(index, $0) }
    }

    private static func appRow(_ index: Int, _ bundleId: String) -> TableGroupView.Row {
        let appUrl = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId)
        let name = appUrl.map(DefaultBrowser.displayName) ?? bundleId
        let subtitle = appUrl == nil ? NSLocalizedString("Not installed on this Mac.", comment: "") : nil
        let remove = AppsUrlsTab.removeButton {
            Preferences.set(ProfileStore.appsKey(index), SlotList.removingBundleId(CachedUserDefaults.string(ProfileStore.appsKey(index)), bundleId))
            refresh()
        }
        return TableGroupView.Row(leftTitle: "    " + name, subTitle: subtitle, rightViews: [remove])
    }

    private static func chooseApps(_ index: Int) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = true
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        guard panel.runModal() == .OK else { return }
        let ids = panel.urls.compactMap { Bundle(url: $0)?.bundleIdentifier }
        Preferences.set(ProfileStore.appsKey(index), SlotList.addingBundleIds(CachedUserDefaults.string(ProfileStore.appsKey(index)), ids))
        refresh()
    }

    private static func makeLayoutPopup(_ index: Int) -> NSPopUpButton {
        let popup = PopupButtonLikeSystemSettings()
        popup.addItem(withTitle: NSLocalizedString("None", comment: ""))
        popup.lastItem?.representedObject = ""
        let current = CachedUserDefaults.string(ProfileStore.layoutKey(index))
        var selectedIndex = 0
        for (offset, action) in WindowLayoutAction.allCases.filter({ $0 != .restore }).enumerated() {
            popup.addItem(withTitle: action.localizedTitle)
            popup.lastItem?.representedObject = action.rawValue
            if action.rawValue == current { selectedIndex = offset + 1 }
        }
        popup.selectItem(at: selectedIndex)
        popup.onAction = { control in
            let raw = (control as? NSPopUpButton)?.selectedItem?.representedObject as? String ?? ""
            Preferences.set(ProfileStore.layoutKey(index), raw)
        }
        return popup
    }

    private static func makeBindingViews(_ index: Int) -> [NSView] {
        let label = TableGroupView.makeText("")
        label.translatesAutoresizingMaskIntoConstraints = false
        bindingLabel = label
        updateBindingLabel(index)
        let bind = NSButton(title: NSLocalizedString("Bind to current space", comment: ""), target: nil, action: nil)
        bind.onAction = { _ in
            Preferences.set(ProfileStore.spaceUuidKey(index), Spaces.currentSpaceUuid ?? "")
            updateBindingLabel(index)
        }
        let clear = NSButton(title: NSLocalizedString("Clear", comment: ""), target: nil, action: nil)
        clear.onAction = { _ in
            Preferences.set(ProfileStore.spaceUuidKey(index), "")
            updateBindingLabel(index)
        }
        return [label, bind, clear]
    }

    private static func updateBindingLabel(_ index: Int) {
        guard let label = bindingLabel else { return }
        let uuid = CachedUserDefaults.string(ProfileStore.spaceUuidKey(index))
        if uuid.isEmpty {
            label.stringValue = NSLocalizedString("Not bound", comment: "")
            label.textColor = .secondaryLabelColor
        } else if SpaceIdentity.isPresent(uuid, in: Spaces.identitySnapshot()) {
            label.stringValue = NSLocalizedString("Bound", comment: "")
            label.textColor = .secondaryLabelColor
        } else {
            label.stringValue = NSLocalizedString("Bound space is gone", comment: "")
            label.textColor = .systemOrange
        }
    }
}
