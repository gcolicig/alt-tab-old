import Cocoa
import UniformTypeIdentifiers

/// One row per app instead of the old 4-column table: name, icon, and two labelled popups
/// (Switcher / Shortcuts), mirroring `AppsUrlsTab`'s row style. Entries still live in
/// `Preferences.exceptions` (same JSON storage as before); only the presentation changed.
class ExceptionsTab {
    static let sectionId = "exceptions"
    private static let container = RebuildableSettingsView(sectionId: sectionId)

    static func initTab() -> NSView {
        container.rebuild(makeViews)
        return container
    }

    private static func refresh() {
        container.rebuild(makeViews)
    }

    private static func makeViews() -> [NSView] {
        [exceptionsTable(), addButtonsRow()]
    }

    // MARK: table

    private static func exceptionsTable() -> TableGroupView {
        let table = TableGroupView(width: SettingsWindow.contentWidth)
        let entries = Preferences.exceptions
        if entries.isEmpty {
            table.addRow(TableGroupView.Row(leftTitle: NSLocalizedString("No exceptions yet.", comment: ""), rightViews: []))
        }
        entries.indices.forEach { addExceptionRow(table, $0, entries[$0]) }
        return table
    }

    private static func addExceptionRow(_ table: TableGroupView, _ index: Int, _ entry: ExceptionEntry) {
        let appUrl = NSWorkspace.shared.urlForApplication(withBundleIdentifier: entry.bundleIdentifier)
        let isPrefix = ExceptionsTestable.isPrefix(entry.bundleIdentifier)
        let name = ExceptionsTestable.displayName(bundleIdentifier: entry.bundleIdentifier, resolvedName: appUrl.map(DefaultBrowser.displayName))
        let subtitle = isPrefix || appUrl != nil ? entry.bundleIdentifier : NSLocalizedString("No installed app matches this entry.", comment: "")
        let secondary = entry.hide == .windowTitleContains ? [titleField(index, entry)] : []
        table.addRow(
            leftViews: [iconView(appUrl: appUrl, isPrefix: isPrefix), nameStack(name, subtitle)],
            rightViews: [switcherPopup(index, entry), shortcutsPopup(index, entry), removeButton(index)],
            secondaryViews: secondary.isEmpty ? nil : secondary)
    }

    private static func iconView(appUrl: URL?, isPrefix: Bool) -> NSImageView {
        let imageView = NSImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.widthAnchor.constraint(equalToConstant: 22).isActive = true
        imageView.heightAnchor.constraint(equalToConstant: 22).isActive = true
        if let appUrl {
            imageView.image = NSWorkspace.shared.icon(forFile: appUrl.path)
        } else if #available(macOS 11.0, *) {
            let symbolName = isPrefix ? "square.stack.3d.up" : "app.dashed"
            imageView.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)
        }
        return imageView
    }

    private static func nameStack(_ name: String, _ subtitle: String) -> NSView {
        let title = TableGroupView.makeText(name, bold: true)
        let subLabel = NSTextField(labelWithString: subtitle)
        subLabel.font = NSFont.systemFont(ofSize: 12)
        subLabel.textColor = .gray
        subLabel.lineBreakMode = .byTruncatingTail
        let stack = NSStackView(views: [title, subLabel])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 2
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }

    private static func switcherPopup(_ index: Int, _ entry: ExceptionEntry) -> NSView {
        let button = PopupButtonLikeSystemSettings()
        ExceptionHidePreference.allCases.forEach { button.addItem(withTitle: $0.localizedString) }
        button.selectItem(at: entry.hide.index)
        button.onAction = { _ in
            let newValue = ExceptionHidePreference.allCases[button.indexOfSelectedItem]
            save(ExceptionsTestable.update(Preferences.exceptions, at: index, hide: newValue))
            refresh()
        }
        return labelledControl(NSLocalizedString("Switcher:", comment: ""), button)
    }

    private static func shortcutsPopup(_ index: Int, _ entry: ExceptionEntry) -> NSView {
        let button = PopupButtonLikeSystemSettings()
        ExceptionIgnorePreference.allCases.forEach { button.addItem(withTitle: $0.localizedString) }
        button.selectItem(at: entry.ignore.index)
        button.onAction = { _ in
            let newValue = ExceptionIgnorePreference.allCases[button.indexOfSelectedItem]
            save(ExceptionsTestable.update(Preferences.exceptions, at: index, ignore: newValue))
        }
        return labelledControl(NSLocalizedString("Shortcuts:", comment: ""), button)
    }

    private static func labelledControl(_ label: String, _ control: NSView) -> NSView {
        let labelView = NSTextField(labelWithString: label)
        labelView.font = NSFont.systemFont(ofSize: 12)
        labelView.textColor = .gray
        control.widthAnchor.constraint(equalToConstant: 170).isActive = true
        let stack = NSStackView(views: [labelView, control])
        stack.orientation = .horizontal
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }

    private static func titleField(_ index: Int, _ entry: ExceptionEntry) -> NSView {
        let label = NSTextField(labelWithString: NSLocalizedString("Hide windows whose title contains", comment: ""))
        label.font = NSFont.systemFont(ofSize: 12)
        label.textColor = .gray
        let field = TextField(entry.windowTitleContains ?? "")
        field.isEditable = true
        field.drawsBackground = true
        field.isBordered = true
        field.usesSingleLineMode = true
        field.widthAnchor.constraint(equalToConstant: 220).isActive = true
        field.cell!.sendsActionOnEndEditing = true
        field.onAction = { _ in save(ExceptionsTestable.update(Preferences.exceptions, at: index, title: field.stringValue)) }
        let stack = NSStackView(views: [label, field])
        stack.orientation = .horizontal
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }

    private static func removeButton(_ index: Int) -> NSButton {
        AppsUrlsTab.removeButton {
            save(ExceptionsTestable.remove(Preferences.exceptions, at: index))
            refresh()
        }
    }

    private static func save(_ entries: [ExceptionEntry]) {
        Preferences.set("exceptions", entries)
    }

    // MARK: add

    private static func addButtonsRow() -> TableGroupView {
        let table = TableGroupView(width: SettingsWindow.contentWidth)
        let addButton = makeCircleButton(systemSymbolName: "plus")
        addButton.onAction = { _ in showAddMenu(sender: addButton) }
        table.addRow(TableGroupView.Row(leftTitle: "", rightViews: [addButton]))
        return table
    }

    private static func makeCircleButton(systemSymbolName: String) -> NSButton {
        let button = NSButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.isBordered = true
        button.bezelStyle = .circular
        button.showsBorderOnlyWhileMouseInside = false
        if #available(macOS 11.0, *) {
            button.image = NSImage(systemSymbolName: systemSymbolName, accessibilityDescription: nil)
        } else {
            button.image = NSImage(named: NSImage.addTemplateName)
        }
        button.imagePosition = .imageOnly
        button.imageScaling = .scaleProportionallyDown
        button.widthAnchor.constraint(equalToConstant: 22).isActive = true
        button.heightAnchor.constraint(equalToConstant: 22).isActive = true
        return button
    }

    private static func showAddMenu(sender: NSButton) {
        let menu = NSMenu()
        let runningAppsItem = NSMenuItem(title: NSLocalizedString("Add a running app", comment: ""), action: nil, keyEquivalent: "")
        runningAppsItem.submenu = buildRunningAppsSubmenu()
        menu.addItem(runningAppsItem)
        let diskItem = NSMenuItem(title: NSLocalizedString("Add an app from disk", comment: ""), action: nil, keyEquivalent: "")
        diskItem.target = ExceptionsTab.self
        diskItem.action = #selector(addFromDisk)
        menu.addItem(diskItem)
        let bundleIdItem = NSMenuItem(title: NSLocalizedString("Add by bundle ID…", comment: ""), action: nil, keyEquivalent: "")
        bundleIdItem.target = ExceptionsTab.self
        bundleIdItem.action = #selector(addByBundleId)
        menu.addItem(bundleIdItem)
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: sender.bounds.height + 2), in: sender)
    }

    @objc private static func addFromDisk() {
        let dialog = NSOpenPanel()
        dialog.allowsMultipleSelection = false
        dialog.allowedContentTypes = [.applicationBundle]
        dialog.canChooseDirectories = false
        dialog.beginSheetModal(for: SettingsWindow.shared) {
            if $0 == .OK, let url = dialog.url, let bundleId = Bundle(url: url)?.bundleIdentifier {
                insert(bundleId)
            }
        }
    }

    @objc private static func addByBundleId() {
        let field = NSTextField(frame: CGRect(x: 0, y: 0, width: 300, height: 24))
        field.placeholderString = "com.example.app"
        let alert = NSAlert()
        alert.messageText = NSLocalizedString("Add by bundle ID", comment: "")
        alert.informativeText = NSLocalizedString("A bundle id, or a prefix ending with a dot to match every app that starts with it, such as com.parallels.", comment: "")
        alert.accessoryView = field
        alert.addButton(withTitle: NSLocalizedString("Add", comment: ""))
        alert.addButton(withTitle: NSLocalizedString("Cancel", comment: ""))
        alert.window.initialFirstResponder = field
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        insert(field.stringValue)
    }

    private static func insert(_ bundleId: String) {
        guard let updated = ExceptionsTestable.insert(Preferences.exceptions, bundleIdentifier: bundleId) else { return }
        save(updated)
        refresh()
    }

    private static func buildRunningAppsSubmenu() -> NSMenu {
        let submenu = NSMenu()
        runningAppsForMenu().forEach { submenu.addItem(makeRunningAppItem($0.app, $0.bundleId)) }
        return submenu
    }

    private static func runningAppsForMenu() -> [(app: NSRunningApplication, bundleId: String)] {
        let existingIds = Set(Preferences.exceptions.map { $0.bundleIdentifier })
        var appsByBundleId = [String: NSRunningApplication]()
        runningAppCandidates().forEach {
            guard let bundleId = $0.bundleIdentifier, !existingIds.contains(bundleId), appsByBundleId[bundleId] == nil else { return }
            appsByBundleId[bundleId] = $0
        }
        return appsByBundleId.map { ($0.value, $0.key) }.sorted { appMenuTitle($0.app).localizedStandardCompare(appMenuTitle($1.app)) == .orderedAscending }
    }

    private static func runningAppCandidates() -> [NSRunningApplication] {
        windowBackedRunningApps() + regularRunningApps()
    }

    private static func windowBackedRunningApps() -> [NSRunningApplication] {
        Windows.list.map { $0.application.runningApplication }
    }

    private static func regularRunningApps() -> [NSRunningApplication] {
        NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular }
    }

    private static func makeRunningAppItem(_ app: NSRunningApplication, _ bundleId: String) -> NSMenuItem {
        let item = NSMenuItem(title: appMenuTitle(app), action: nil, keyEquivalent: "")
        if let path = app.bundleURL?.path {
            let icon = NSWorkspace.shared.icon(forFile: path)
            icon.size = NSSize(width: 16, height: 16)
            item.image = icon
        }
        item.representedObject = bundleId
        item.target = ExceptionsTab.self
        item.action = #selector(addRunningApp(_:))
        return item
    }

    private static func appMenuTitle(_ app: NSRunningApplication) -> String {
        app.localizedName ?? app.bundleIdentifier ?? ""
    }

    @objc private static func addRunningApp(_ sender: NSMenuItem) {
        guard let bundleId = sender.representedObject as? String else { return }
        insert(bundleId)
    }
}
