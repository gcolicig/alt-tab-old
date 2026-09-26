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
    static let sectionId = "system-actions"
    private static let container = RebuildableSettingsView(sectionId: sectionId)

    static func initTab() -> NSView {
        container.rebuild(makeViews)
        return container
    }

    private static func refresh() {
        container.rebuild(makeViews)
    }

    private static func makeViews() -> [NSView] {
        let autoQuit = TableGroupView(title: NSLocalizedString("Auto-Quit Apps", comment: ""),
            subTitle: NSLocalizedString("Quits an app some time after its last window closed, unless it opened a new window or came to the front meanwhile. Finder, menu bar apps and apps with their own menu bar item keep running.", comment: ""),
            width: SettingsWindow.contentWidth)
        autoQuit.addRow(TableGroupView.Row(leftTitle: NSLocalizedString("Enable Auto-Quit", comment: ""), rightViews: [LabelAndControl.makeSwitch("autoQuitEnabled")]))
        autoQuit.addRow(TableGroupView.Row(leftTitle: NSLocalizedString("Delay", comment: ""), rightViews: [SettingsControls.valuePopup("autoQuitDelaySeconds", delayOptions)]))
        autoQuit.addRow(TableGroupView.Row(leftTitle: NSLocalizedString("Apps affected", comment: ""), rightViews: [SettingsControls.valuePopup("autoQuitMode", modeOptions)]))
        let appList = appListTable(
            title: NSLocalizedString("App list", comment: ""),
            entries: AutoQuitPolicy.decodeList(Preferences.autoQuitBundleIds),
            onAdd: { AutoQuit.addApps($0); refresh() },
            onRemove: { AutoQuit.removeApp($0); refresh() })
        let menuBarExceptions = appListTable(
            title: NSLocalizedString("Quit even with a menu bar item", comment: ""),
            subTitle: NSLocalizedString("These apps quit although they keep an item in the menu bar, which then disappears too.", comment: ""),
            entries: AutoQuit.menuBarExceptions.sorted(),
            onAdd: { AutoQuit.addMenuBarExceptions($0); refresh() },
            onRemove: { AutoQuit.removeMenuBarException($0); refresh() })
        let catMode = TableGroupView(title: NSLocalizedString("Cat Mode", comment: ""),
            subTitle: NSLocalizedString("Locks the keyboard. End it from the menu, by typing “unlock”, or with the emergency shortcut ⌃⌥⇧⌘⎋.", comment: ""),
            width: SettingsWindow.contentWidth)
        catMode.addRow(TableGroupView.Row(leftTitle: NSLocalizedString("End automatically after", comment: ""), rightViews: [SettingsControls.valuePopup("catModeMinutes", catModeOptions)]))
        let microphone = TableGroupView(title: NSLocalizedString("Microphone", comment: ""), width: SettingsWindow.contentWidth)
        let micMuteIndicatorFullText = NSLocalizedString("The icons appear at the right end of the AltTab+ menu bar item, after the Spaces. macOS has no indicator for a muted microphone. Click an icon to unmute.", comment: "")
        microphone.addRow(TableGroupView.Row(leftTitle: NSLocalizedString("Show an icon in the menu bar while the microphone or the sound is muted", comment: ""),
            subTitle: NSLocalizedString("Click the icon to unmute.", comment: ""),
            rightViews: [LabelAndControl.makeInfoButton(searchableTooltipTexts: [micMuteIndicatorFullText], onMouseEntered: { event, view in
                Popover.shared.show(event: event, positioningView: view, message: micMuteIndicatorFullText)
            }, onMouseExited: { _, _ in Popover.shared.hide() }), LabelAndControl.makeSwitch("micMuteIndicator")]))
        let micKeyFullText = NSLocalizedString("The microphone key in the F5 position toggles the mute instead of starting Dictation. After AltTab+ quits, the key starts Dictation again.", comment: "")
        microphone.addRow(TableGroupView.Row(leftTitle: NSLocalizedString("Microphone key mutes the microphone", comment: ""),
            subTitle: NSLocalizedString("Overrides Dictation while AltTab+ runs.", comment: ""),
            rightViews: [LabelAndControl.makeInfoButton(searchableTooltipTexts: [micKeyFullText], onMouseEntered: { event, view in
                Popover.shared.show(event: event, positioningView: view, message: micKeyFullText)
            }, onMouseExited: { _, _ in Popover.shared.hide() }), LabelAndControl.makeSwitch("micKeyMutesMicrophone", extraAction: { _ in MicKey.settingChanged() })]))
        microphone.addRow(TableGroupView.Row(leftTitle: NSLocalizedString("Sync Teams mute with microphone", comment: ""),
            subTitle: NSLocalizedString("Teams is muted automatically when the microphone is muted. It is unmuted only directly after an AltTab+ microphone action.", comment: ""),
            rightViews: [LabelAndControl.makeSwitch("teamsMuteSync")]))
        let typingMuteFullText = NSLocalizedString("Works like Unclack: while you type, the microphones in use go silent, and they open again shortly after the last key. It lowers the input volume, so Teams does not report a muted microphone; a microphone without a volume control is muted instead, and Teams then shows its notice. The first key of a burst can still be heard.", comment: "")
        microphone.addRow(TableGroupView.Row(leftTitle: NSLocalizedString("Mute the microphone while typing", comment: ""),
            subTitle: NSLocalizedString("Only while an app uses the microphone. The microphone key always wins.", comment: ""),
            rightViews: [LabelAndControl.makeInfoButton(searchableTooltipTexts: [typingMuteFullText], onMouseEntered: { event, view in
                Popover.shared.show(event: event, positioningView: view, message: typingMuteFullText)
            }, onMouseExited: { _, _ in Popover.shared.hide() }), LabelAndControl.makeSwitch("typingMuteEnabled")]))
        microphone.addRow(TableGroupView.Row(leftTitle: NSLocalizedString("Open again after the last key", comment: ""),
            rightViews: [SettingsControls.valuePopup("typingMuteHoldMs", typingMuteHoldOptions)]))
        let keys = TableGroupView(title: NSLocalizedString("Function Keys", comment: ""), width: SettingsWindow.contentWidth)
        let restore = NSButton(title: NSLocalizedString("Restore original mode", comment: ""), target: nil, action: nil)
        restore.onAction = { _ in FunctionKeys.releaseOwnership() }
        keys.addRow(TableGroupView.Row(leftTitle: NSLocalizedString("Give back the function key mode from before AltTab+ changed it", comment: ""), rightViews: [restore]))
        return [autoQuit, appList, menuBarExceptions, catMode, microphone, keys]
    }

    private static let delayOptions: [(String, Int)] = [0, 5, 10, 30, 60, 120, 300].map { (String(format: NSLocalizedString("%d s", comment: ""), $0), $0) }
    private static let typingMuteHoldOptions: [(String, Int)] = [150, 250, 400, 600, 800, 1000, 1500].map { (String(format: NSLocalizedString("%d ms", comment: ""), $0), $0) }
    private static let catModeOptions: [(String, Int)] = [5, 15, 30, 60, 120, 240].map { (String(format: NSLocalizedString("%d min", comment: ""), $0), $0) }
    private static let modeOptions: [(String, Int)] = [
        (NSLocalizedString("Only apps in the list", comment: ""), AutoQuitMode.onlyListed.rawValue),
        (NSLocalizedString("All apps except the list", comment: ""), AutoQuitMode.allExceptListed.rawValue),
    ]

    /// One titled list per Auto-Quit app set: a row per app (icon, name, bundle id, ⊖), an empty-state
    /// row when there is nothing yet, and a "+" button that opens the same `chooseApps()` panel Exceptions uses.
    private static func appListTable(title: String, subTitle: String? = nil, entries: [String],
                                      onAdd: @escaping ([String]) -> Void, onRemove: @escaping (String) -> Void) -> TableGroupView {
        let table = TableGroupView(title: title, subTitle: subTitle, width: SettingsWindow.contentWidth)
        if entries.isEmpty {
            table.addRow(TableGroupView.Row(leftTitle: NSLocalizedString("No apps yet.", comment: ""), rightViews: []))
        }
        entries.forEach { bundleId in
            table.addRow(leftViews: [AppListRows.appView(bundleId: bundleId)],
                rightViews: [AppListRows.removeButton { onRemove(bundleId) }], secondaryViews: nil)
        }
        let addButton = AppListRows.makeCircleButton(systemSymbolName: "plus")
        addButton.onAction = { _ in chooseApps().map(onAdd) }
        table.addRow(TableGroupView.Row(leftTitle: "", rightViews: [addButton]))
        return table
    }

    private static func chooseApps() -> [String]? {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = true
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        guard panel.runModal() == .OK else { return nil }
        return panel.urls.compactMap { Bundle(url: $0)?.bundleIdentifier }
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
        let startAndStop = TableGroupView(title: NSLocalizedString("Start and stop", comment: ""), width: SettingsWindow.contentWidth)
        startAndStopActions.forEach { action in
            guard let spec = SystemActions.spec(action) else { return }
            startAndStop.addRow(TableGroupView.Row(leftTitle: SentenceCase.fromTitleCase(spec.title), rightViews: [SettingsControls.recorder(action, spec.title)]))
        }
        let durations = TableGroupView(title: NSLocalizedString("Durations", comment: ""), width: SettingsWindow.contentWidth)
        durationActions.forEach { action in
            guard let spec = SystemActions.spec(action) else { return }
            durations.addRow(TableGroupView.Row(leftTitle: SentenceCase.fromTitleCase(spec.title), rightViews: [SettingsControls.recorder(action, spec.title)]))
        }
        return TableGroupSetView(originalViews: [table, startAndStop, durations], padding: 0, bottomPadding: 0)
    }

    /// Their shortcuts are assigned here only; one recorder per preference keeps the two tabs from fighting.
    static let actions: [SystemAction] = [.keepAwakeToggle, .keepAwakeIndefinitely, .keepAwake15Minutes, .keepAwake1Hour, .keepAwake2Hours, .keepAwake5Hours, .keepAwakeStop]
    static let startAndStopActions: [SystemAction] = [.keepAwakeToggle, .keepAwakeIndefinitely, .keepAwakeStop]
    static let durationActions: [SystemAction] = [.keepAwake15Minutes, .keepAwake1Hour, .keepAwake2Hours, .keepAwake5Hours]

    private static let batteryOptions: [(String, Int)] = [(NSLocalizedString("Never", comment: ""), 0)] + [10, 20, 30, 50].map { ("\($0) %", $0) }
}
