import Cocoa

/// Story 16, stage 2: only the filled app and URL slots, as a list. New entries take the first free slot;
/// removing one empties its slot and never moves the others, so bindings keep pointing at the same entry.
class AppsUrlsTab {
    private static let container = RebuildableSettingsView()

    static func initTab() -> NSView {
        container.rebuild(makeViews)
        return container
    }

    private static func refresh() {
        container.rebuild(makeViews)
    }

    private static func makeViews() -> [NSView] {
        [appsTable(), urlsTable()]
    }

    // MARK: apps

    private static func appValues() -> [String] {
        (0..<Preferences.maxLaunchAppCount).map(Preferences.launchAppBundleIdentifier)
    }

    private static func appsTable() -> TableGroupView {
        let table = TableGroupView(title: NSLocalizedString("Apps", comment: ""), width: SettingsWindow.contentWidth)
        let slots = SlotList.occupied(appValues())
        if slots.isEmpty {
            table.addRow(TableGroupView.Row(leftTitle: NSLocalizedString("No apps yet. Add one to open it with a shortcut.", comment: ""), rightViews: []))
        }
        slots.forEach { table.addRow(appRow($0)) }
        table.addRow(TableGroupView.Row(leftTitle: "", rightViews: [addButton(NSLocalizedString("Add App…", comment: ""), appValues(), chooseApps)]))
        return table
    }

    private static func appRow(_ index: Int) -> TableGroupView.Row {
        let value = Preferences.launchAppBundleIdentifier(index)
        let appUrl = NSWorkspace.shared.urlForApplication(withBundleIdentifier: value)
        let title = appUrl.map(DefaultBrowser.displayName) ?? value
        let subtitle = LaunchAppAction.isMisconfigured(index) ? NSLocalizedString("No installed app matches this entry.", comment: "") : nil
        let row = TableGroupView.Row(leftTitle: title, subTitle: subtitle,
            rightViews: [recorder(LaunchAppAction.shortcutPreferenceKey(index), title), removeButton { clearApp(index) }])
        return row
    }

    private static func chooseApps() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = true
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        guard panel.runModal() == .OK else { return }
        panel.urls.compactMap { Bundle(url: $0)?.bundleIdentifier }.forEach(addApp)
        refresh()
    }

    private static func addApp(_ bundleId: String) {
        guard !appValues().contains(bundleId) else { return }
        guard let slot = SlotList.firstFree(appValues()) else { return announceFull() }
        Preferences.set(Preferences.indexToName("launchAppBundleIdentifier", slot), bundleId)
    }

    private static func clearApp(_ index: Int) {
        Preferences.set(Preferences.indexToName("launchAppBundleIdentifier", index), "")
        Preferences.setShortcut(LaunchAppAction.shortcutPreferenceKey(index), nil)
        refresh()
    }

    // MARK: urls

    private static func urlValues() -> [String] {
        (0..<Preferences.maxOpenUrlCount).map(Preferences.openUrlValue)
    }

    private static func urlsTable() -> TableGroupView {
        let table = TableGroupView(title: NSLocalizedString("Links", comment: ""), width: SettingsWindow.contentWidth)
        let slots = SlotList.occupied(urlValues())
        if slots.isEmpty {
            table.addRow(TableGroupView.Row(leftTitle: NSLocalizedString("No links yet. Add one to open it with a shortcut.", comment: ""), rightViews: []))
        }
        slots.forEach { table.addRow(urlRow($0)) }
        table.addRow(TableGroupView.Row(leftTitle: "", rightViews: [addButton(NSLocalizedString("Add Link…", comment: ""), urlValues(), askUrl)]))
        return table
    }

    private static func urlRow(_ index: Int) -> TableGroupView.Row {
        let value = Preferences.openUrlValue(index)
        let subtitle = OpenUrlAction.isMisconfigured(index) ? NSLocalizedString("The URL is invalid.", comment: "") : nil
        return TableGroupView.Row(leftTitle: value, subTitle: subtitle,
            rightViews: [recorder(OpenUrlAction.shortcutPreferenceKey(index), value), removeButton { clearUrl(index) }])
    }

    /// Asks again with the reason until the entry is valid or the user cancels.
    private static func askUrl() {
        var message: String?
        while let entry = promptUrl(message) {
            guard OpenUrlTarget.normalized(entry) != nil else {
                message = NSLocalizedString("That is not a valid link. Try a web address such as github.com.", comment: "")
                continue
            }
            guard let slot = SlotList.firstFree(urlValues()) else { return announceFull() }
            Preferences.set(Preferences.indexToName("openUrlValue", slot), entry.trimmingCharacters(in: .whitespacesAndNewlines))
            return refresh()
        }
    }

    private static func promptUrl(_ message: String?) -> String? {
        let field = NSTextField(frame: CGRect(x: 0, y: 0, width: 300, height: 24))
        field.placeholderString = "https://github.com"
        let alert = NSAlert()
        alert.messageText = NSLocalizedString("Add link", comment: "")
        alert.informativeText = message ?? NSLocalizedString("A web address, or a link of another app such as mailto: or raycast://", comment: "")
        alert.accessoryView = field
        alert.addButton(withTitle: NSLocalizedString("Add", comment: ""))
        alert.addButton(withTitle: NSLocalizedString("Cancel", comment: ""))
        alert.window.initialFirstResponder = field
        return alert.runModal() == .alertFirstButtonReturn ? field.stringValue : nil
    }

    private static func clearUrl(_ index: Int) {
        Preferences.set(Preferences.indexToName("openUrlValue", index), "")
        Preferences.setShortcut(OpenUrlAction.shortcutPreferenceKey(index), nil)
        refresh()
    }

    // MARK: shared

    private static func recorder(_ key: String, _ title: String) -> NSView {
        LabelAndControl.makeLabelWithRecorder(title, key, Preferences.shortcut(key))[1]
    }

    static func removeButton(_ action: @escaping () -> Void) -> NSButton {
        let button = NSButton(title: NSLocalizedString("Remove", comment: ""), target: nil, action: nil)
        button.onAction = { _ in action() }
        return button
    }

    private static func addButton(_ title: String, _ values: [String], _ action: @escaping () -> Void) -> NSButton {
        let button = NSButton(title: title, target: nil, action: nil)
        button.onAction = { _ in action() }
        if SlotList.firstFree(values) == nil {
            button.isEnabled = false
            button.toolTip = NSLocalizedString("All 9 places are in use. Remove an entry first.", comment: "")
        }
        return button
    }

    private static func announceFull() {
        TransientNotice.show(NSLocalizedString("All 9 places are in use. Remove an entry first.", comment: ""))
    }
}

/// A settings page whose content is rebuilt when its list changes.
final class RebuildableSettingsView: NSStackView {
    func rebuild(_ content: () -> [NSView]) {
        orientation = .vertical
        alignment = .leading
        arrangedSubviews.forEach { $0.removeFromSuperview() }
        addArrangedSubview(TableGroupSetView(originalViews: content(), padding: 0, bottomPadding: 0))
    }
}
