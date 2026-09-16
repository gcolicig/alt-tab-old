import Cocoa

/// Settings for stories 10, 14 and 15, kept apart from the older tabs they would otherwise crowd.
enum SettingsControls {
    /// An integer preference offered as a short list of labelled values.
    static func valuePopup(_ key: String, _ options: [(String, Int)], onChange: (() -> Void)? = nil) -> NSPopUpButton {
        let popup = PopupButtonLikeSystemSettings()
        options.forEach { popup.addItem(withTitle: $0.0) }
        let current = CachedUserDefaults.int(key)
        popup.selectItem(at: options.firstIndex { $0.1 == current } ?? 0)
        popup.onAction = { control in
            guard let index = (control as? NSPopUpButton)?.indexOfSelectedItem, options.indices.contains(index) else { return }
            Preferences.set(key, String(options[index].1))
            onChange?()
        }
        return popup
    }

    static func recorder(_ action: SystemAction, _ title: String) -> NSView {
        LabelAndControl.makeLabelWithRecorder(title, action.shortcutPreferenceKey, Preferences.shortcut(action.shortcutPreferenceKey))[1]
    }
}

class SystemActionsTab {
    private static var appListStack: NSStackView?

    static func initTab() -> NSView {
        let autoQuit = TableGroupView(title: NSLocalizedString("Auto-Quit Apps", comment: ""),
            subTitle: NSLocalizedString("Quits an app some time after its last window closed, unless it opened a new window or came to the front meanwhile. Finder is never quit.", comment: ""),
            width: SettingsWindow.contentWidth)
        autoQuit.addRow(TableGroupView.Row(leftTitle: NSLocalizedString("Enable Auto-Quit", comment: ""), rightViews: [LabelAndControl.makeSwitch("autoQuitEnabled")]))
        autoQuit.addRow(TableGroupView.Row(leftTitle: NSLocalizedString("Delay", comment: ""), rightViews: [SettingsControls.valuePopup("autoQuitDelaySeconds", delayOptions)]))
        autoQuit.addRow(TableGroupView.Row(leftTitle: NSLocalizedString("Apps affected", comment: ""), rightViews: [SettingsControls.valuePopup("autoQuitMode", modeOptions)]))
        autoQuit.addRow(TableGroupView.Row(leftTitle: NSLocalizedString("App list", comment: ""), rightViews: [appListView()]))
        let catMode = TableGroupView(title: NSLocalizedString("Cat Mode", comment: ""),
            subTitle: NSLocalizedString("Locks the keyboard. End it from the menu, by typing “unlock”, or with the emergency shortcut ⌃⌥⇧⌘⎋.", comment: ""),
            width: SettingsWindow.contentWidth)
        catMode.addRow(TableGroupView.Row(leftTitle: NSLocalizedString("End automatically after", comment: ""), rightViews: [SettingsControls.valuePopup("catModeMinutes", catModeOptions)]))
        let microphone = TableGroupView(title: NSLocalizedString("Microphone", comment: ""), width: SettingsWindow.contentWidth)
        microphone.addRow(TableGroupView.Row(leftTitle: NSLocalizedString("Show an icon in the menu bar while the microphone is muted", comment: ""),
            subTitle: NSLocalizedString("macOS has no indicator for a muted microphone. Click the icon to unmute.", comment: ""),
            rightViews: [LabelAndControl.makeSwitch("micMuteIndicator")]))
        let keys = TableGroupView(title: NSLocalizedString("Function Keys", comment: ""), width: SettingsWindow.contentWidth)
        let restore = NSButton(title: NSLocalizedString("Restore Original Mode", comment: ""), target: nil, action: nil)
        restore.onAction = { _ in FunctionKeys.releaseOwnership() }
        keys.addRow(TableGroupView.Row(leftTitle: NSLocalizedString("Give back the function key mode from before AltTab+ changed it", comment: ""), rightViews: [restore]))
        return TableGroupSetView(originalViews: [autoQuit, catMode, microphone, keys], bottomPadding: 0)
    }

    private static let delayOptions: [(String, Int)] = [0, 5, 10, 30, 60, 120, 300].map { (String(format: NSLocalizedString("%d s", comment: ""), $0), $0) }
    private static let catModeOptions: [(String, Int)] = [5, 15, 30, 60, 120, 240].map { (String(format: NSLocalizedString("%d min", comment: ""), $0), $0) }
    private static let modeOptions: [(String, Int)] = [
        (NSLocalizedString("Only apps in the list", comment: ""), AutoQuitMode.onlyListed.rawValue),
        (NSLocalizedString("All apps except the list", comment: ""), AutoQuitMode.allExceptListed.rawValue),
    ]

    private static func appListView() -> NSView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .trailing
        appListStack = stack
        refreshAppList()
        return stack
    }

    static func refreshAppList() {
        guard let stack = appListStack else { return }
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        AutoQuitPolicy.decodeList(Preferences.autoQuitBundleIds).forEach { stack.addArrangedSubview(appRow($0)) }
        let add = NSButton(title: NSLocalizedString("Add App…", comment: ""), target: nil, action: nil)
        add.onAction = { _ in chooseApps() }
        stack.addArrangedSubview(add)
    }

    private static func appRow(_ bundleId: String) -> NSView {
        let name = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId).map(DefaultBrowser.displayName) ?? bundleId
        let remove = NSButton(title: NSLocalizedString("Remove", comment: ""), target: nil, action: nil)
        remove.onAction = { _ in
            AutoQuit.removeApp(bundleId)
            refreshAppList()
        }
        return StackView([NSTextField(labelWithString: name), remove])
    }

    private static func chooseApps() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = true
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        guard panel.runModal() == .OK else { return }
        AutoQuit.addApps(panel.urls.compactMap { Bundle(url: $0)?.bundleIdentifier })
        refreshAppList()
    }
}

class KeepAwakeTab {
    static func initTab() -> NSView {
        let table = TableGroupView(width: SettingsWindow.contentWidth)
        table.addRow(TableGroupView.Row(leftTitle: NSLocalizedString("Duration when turned on", comment: ""),
            rightViews: [SettingsControls.valuePopup("keepAwakeLastDuration", KeepAwakeDuration.allCases.map { (SubmenuBuilder.durationTitle($0), $0.rawValue) })]))
        table.addRow(TableGroupView.Row(leftTitle: NSLocalizedString("Keep the display awake too", comment: ""),
            subTitle: NSLocalizedString("Off: only the Mac stays awake; the display may sleep and the screen saver may start.", comment: ""),
            rightViews: [LabelAndControl.makeSwitch("keepAwakeDisplay")]))
        table.addRow(TableGroupView.Row(leftTitle: NSLocalizedString("End on battery at", comment: ""),
            rightViews: [SettingsControls.valuePopup("keepAwakeBatteryThreshold", batteryOptions)]))
        table.addNewTable()
        actions.forEach { action in
            guard let spec = SystemActions.spec(action) else { return }
            table.addRow(TableGroupView.Row(leftTitle: spec.title, rightViews: [SettingsControls.recorder(action, spec.title)]))
        }
        return TableGroupSetView(originalViews: [table], bottomPadding: 0)
    }

    /// Their shortcuts are assigned here only; one recorder per preference keeps the two tabs from fighting.
    static let actions: [SystemAction] = [.keepAwakeToggle, .keepAwakeIndefinitely, .keepAwake15Minutes, .keepAwake1Hour, .keepAwake2Hours, .keepAwake5Hours, .keepAwakeStop]

    private static let batteryOptions: [(String, Int)] = [(NSLocalizedString("Never", comment: ""), 0)] + [10, 20, 30, 50].map { ("\($0) %", $0) }
}
