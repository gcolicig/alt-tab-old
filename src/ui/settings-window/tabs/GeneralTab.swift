import Cocoa
import UniformTypeIdentifiers

class GeneralTab {
    static var menubarIconDropdown: NSPopUpButton?
    static var menubarIconNote: NSTextField?
    static var captureWindowsInBackgroundRowInfo: TableGroupView.RowInfo?
    static var captureWindowsInBackgroundNote: NSTextField?
    static var policyLock = false
    private static var accessibilityStatusLabel: NSTextField?
    private static var accessibilityOpenSettingsButton: NSButton?
    private static var screenRecordingStatusLabel: NSTextField?
    private static var screenRecordingOpenSettingsButton: NSButton?
    private static var menubarIsVisibleObserver: NSKeyValueObservation?

    static func initTab() -> NSView {
        let startAtLogin = TableGroupView.Row(leftTitle: NSLocalizedString("Start at login", comment: ""),
            rightViews: [LabelAndControl.makeSwitch("startAtLogin")])
        menubarIconDropdown = LabelAndControl.makeDropdown("menubarIcon", MenubarIconPreference.allCases)
        let menuIconShownToggle = LabelAndControl.makeSwitch("menubarIconShown")
        menubarIconNote = LabelAndControl.makeDependencyNote(
            NSLocalizedString("Enable the menu bar icon to choose its style.", comment: ""))
        let language = TableGroupView.Row(leftTitle: NSLocalizedString("Language", comment: ""),
            rightViews: [LabelAndControl.makeDropdown("language", LanguagePreference.allCases, extraAction: setLanguageCallback)])
        // 0 is the two-tone glyph the status item draws, 1 the same glyph as a template
        for i in 0..<MenubarIconPreference.allCases.count {
            let image = i == 0 ? Menubar.focusGlyph(dark: NSApp.effectiveAppearance.getThemeName() == .dark) : NSImage.initCopy("menubar-\(i)")
            image.isTemplate = i == 1
            menubarIconDropdown!.item(at: i)!.image = image
        }
        let cell = menubarIconDropdown!.cell! as! NSPopUpButtonCell
        cell.bezelStyle = .regularSquare
        cell.arrowPosition = .arrowAtBottom
        cell.imagePosition = .imageOverlaps
        enableDraggingOffMenubarIcon(menuIconShownToggle)
        captureWindowsInBackgroundNote = LabelAndControl.makeDependencyNote(
            NSLocalizedString("Available when window thumbnails are shown, either as the Thumbnails style or as the preview of the selected window in Windows mode.", comment: ""))
        let table = TableGroupView(width: SettingsWindow.contentWidth)
        table.addRow(startAtLogin)
        table.addRow(leftViews: [TableGroupView.makeText(NSLocalizedString("Menubar icon", comment: ""))],
            rightViews: [menubarIconDropdown!, menuIconShownToggle],
            secondaryViews: [menubarIconNote!])
        captureWindowsInBackgroundRowInfo = table.addRow(
            leftViews: [TableGroupView.makeText(NSLocalizedString("Keep window previews up to date in the background", comment: ""))],
            rightViews: [LabelAndControl.makeSwitch("captureWindowsInBackground")],
            secondaryViews: [
                makeSubtitleLabel(NSLocalizedString("Keeps thumbnail and full-size previews current while the switcher is hidden. Turning this off avoids the screen-recording indicator and possible DRM interruptions; required previews refresh when the switcher opens.", comment: "")),
                captureWindowsInBackgroundNote!,
            ], secondaryViewsOrientation: .vertical)
        updateCaptureWindowsInBackgroundState()
        updateMenubarIconDropdownState()
        table.addNewTable()
        table.addRow(language)
        return TableGroupSetView(originalViews: [table, permissionsTable(), settingsFileTable()], bottomPadding: 0)
    }

    private static func permissionsTable() -> TableGroupView {
        let table = TableGroupView(title: NSLocalizedString("Permissions", comment: ""), width: SettingsWindow.contentWidth)
        let accessibilityStatus = NSTextField(labelWithString: "")
        let accessibilityButton = NSButton(title: NSLocalizedString("Open System Settings", comment: ""), target: nil, action: nil)
        accessibilityButton.onAction = { _ in
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
        }
        table.addRow(TableGroupView.Row(leftTitle: NSLocalizedString("Accessibility", comment: ""),
            rightViews: [accessibilityStatus, accessibilityButton]))
        accessibilityStatusLabel = accessibilityStatus
        accessibilityOpenSettingsButton = accessibilityButton
        if #available(macOS 10.15, *) {
            let screenRecordingStatus = NSTextField(labelWithString: "")
            let screenRecordingButton = NSButton(title: NSLocalizedString("Open System Settings", comment: ""), target: nil, action: nil)
            screenRecordingButton.onAction = { _ in ScreenRecordingPermission.requestAccessAndOpenSettings() }
            table.addRow(TableGroupView.Row(leftTitle: NSLocalizedString("Screen Recording", comment: ""),
                rightViews: [screenRecordingStatus, screenRecordingButton]))
            screenRecordingStatusLabel = screenRecordingStatus
            screenRecordingOpenSettingsButton = screenRecordingButton
        }
        refreshPermissionsRows()
        return table
    }

    /// Called whenever the settings window is (re)shown, since the user grants or revokes permissions in
    /// System Settings while AltTab+ keeps running — no polling is added here, this piggybacks on the
    /// existing `refreshControlsFromPreferences` call.
    static func refreshPermissionsRows() {
        AccessibilityPermission.update()
        accessibilityStatusLabel?.stringValue = permissionStatusText(AccessibilityPermission.status)
        accessibilityOpenSettingsButton?.isHidden = AccessibilityPermission.status == .granted
        if #available(macOS 10.15, *) {
            ScreenRecordingPermission.update()
            screenRecordingStatusLabel?.stringValue = permissionStatusText(ScreenRecordingPermission.status)
            screenRecordingOpenSettingsButton?.isHidden = ScreenRecordingPermission.status == .granted
        }
    }

    private static func permissionStatusText(_ status: PermissionStatus) -> String {
        switch status {
            case .granted: return NSLocalizedString("Granted", comment: "")
            case .notGranted: return NSLocalizedString("Not granted", comment: "")
            case .skipped: return NSLocalizedString("Skipped", comment: "")
        }
    }

    /// Story 16: moved here from the bottom of the sidebar, next to export and import.
    private static func settingsFileTable() -> TableGroupView {
        let table = TableGroupView(title: NSLocalizedString("Settings file", comment: ""), width: SettingsWindow.contentWidth)
        let exportButton = NSButton(title: NSLocalizedString("Export…", comment: ""), target: nil, action: nil)
        exportButton.onAction = { _ in exportSettings() }
        let importButton = NSButton(title: NSLocalizedString("Import…", comment: ""), target: nil, action: nil)
        importButton.onAction = { _ in importSettings() }
        table.addRow(TableGroupView.Row(leftTitle: NSLocalizedString("Export or import your settings", comment: ""), rightViews: [exportButton, importButton]))
        let creatorButton = NSButton(title: NSLocalizedString("Apply…", comment: ""), target: nil, action: nil)
        creatorButton.onAction = { _ in applyCreatorSettings() }
        table.addRow(TableGroupView.Row(leftTitle: NSLocalizedString("Creator's settings", comment: ""), rightViews: [creatorButton]))
        let resetButton = NSButton(title: NSLocalizedString("Reset…", comment: ""), target: nil, action: nil)
        if #available(macOS 11.0, *) { resetButton.hasDestructiveAction = true }
        resetButton.onAction = { _ in resetPreferences() }
        table.addRow(TableGroupView.Row(leftTitle: NSLocalizedString("Reset all settings", comment: ""),
            subTitle: NSLocalizedString("AltTab+ restarts afterwards.", comment: ""), rightViews: [resetButton]))
        return table
    }

    /// Overwrites shortcut assignments and appearance, so it asks first. The summary names every input
    /// module the set arms, as the Q-08 carve-out requires.
    static func applyCreatorSettings() {
        let alert = NSAlert()
        alert.messageText = NSLocalizedString("Apply the creator's settings?", comment: "")
        alert.informativeText = NSLocalizedString("This replaces your current appearance and shortcut assignments.", comment: "")
        alert.accessoryView = CreatorSettings.summaryView(width: 420)
        alert.addButton(withTitle: NSLocalizedString("Apply", comment: ""))
        alert.addButton(withTitle: NSLocalizedString("Cancel", comment: ""))
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        CreatorSettings.apply()
        refreshControlsFromPreferences()
        App.restart()
    }

    static func refreshControlsFromPreferences() {
        menubarIconDropdown?.selectItem(at: CachedUserDefaults.intFromMacroPref("menubarIcon", MenubarIconPreference.allCases))
        updateMenubarIconDropdownState()
        updateCaptureWindowsInBackgroundState()
        refreshPermissionsRows()
    }

    static func updateCaptureWindowsInBackgroundState() {
        guard let rowInfo = captureWindowsInBackgroundRowInfo else { return }
        let isEnabled = Preferences.usesImageBasedWindowPreviews
        rowInfo.leftViews?.compactMap { $0 as? NSTextField }.forEach {
            $0.textColor = isEnabled ? .textColor : .gray
        }
        rowInfo.rightViews?.compactMap { $0 as? Switch }.forEach {
            $0.setStateWithoutAction(isEnabled && Preferences.captureWindowsInBackground ? .on : .off)
            $0.isEnabled = isEnabled
        }
        captureWindowsInBackgroundNote?.isHidden = isEnabled
    }

    /// Also called from `Menubar.menubarIconCallback`, which is the path that reacts to the
    /// `menubarIconShown` preference actually changing (both at startup and from the toggle above).
    static func updateMenubarIconDropdownState() {
        let isEnabled = Preferences.menubarIconShown
        menubarIconDropdown?.isEnabled = isEnabled
        menubarIconNote?.isHidden = isEnabled
    }

    private static func makeSubtitleLabel(_ text: String) -> NSTextField {
        let label = NSTextField(wrappingLabelWithString: text)
        label.font = NSFont.systemFont(ofSize: 12)
        label.textColor = .gray
        return label
    }

    private static func enableDraggingOffMenubarIcon(_ menuIconShownToggle: Switch) {
        Menubar.statusItem.behavior = .removalAllowed
        menubarIsVisibleObserver = Menubar.statusItem.observe(\.isVisible, options: [.old, .new]) { _, change in
            Logger.debug { "---- \(change)" }
            if change.oldValue == true && change.newValue == false {
                menuIconShownToggle.state = .off
                LabelAndControl.controlWasChanged(menuIconShownToggle, nil)
            }
        }
    }

    @objc static func resetPreferences() {
        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = ""
        alert.informativeText = NSLocalizedString("You can’t undo this action.", comment: "")
        alert.addButton(withTitle: NSLocalizedString("Cancel", comment: ""))
        let resetButton = alert.addButton(withTitle: NSLocalizedString("Reset settings and restart", comment: ""))
        if #available(macOS 11.0, *) { resetButton.hasDestructiveAction = true }
        if alert.runModal() == .alertSecondButtonReturn {
            Preferences.resetAll()
            App.restart()
        }
    }

    private static func exportSettings() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "\(App.bundleIdentifier).plist"
        panel.allowedContentTypes = [.propertyList]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        NSDictionary(dictionary: Preferences.all).write(to: url, atomically: true)
    }

    private static func importSettings() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.propertyList]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard let dict = NSDictionary(contentsOf: url) as? [String: Any] else {
            let alert = NSAlert()
            alert.alertStyle = .critical
            alert.messageText = NSLocalizedString("Failed to import settings", comment: "")
            alert.runModal()
            return
        }
        UserDefaults.standard.setPersistentDomain(dict, forName: App.bundleIdentifier)
        CachedUserDefaults.cache.withLock { $0.removeAll() }
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = NSLocalizedString("Settings imported", comment: "")
        alert.informativeText = NSLocalizedString("The application needs to restart to apply the imported settings.", comment: "")
        alert.addButton(withTitle: NSLocalizedString("Restart Now", comment: ""))
        alert.addButton(withTitle: NSLocalizedString("Later", comment: ""))
        if alert.runModal() == .alertFirstButtonReturn {
            App.restart()
        }
    }

    static func setLanguageCallback(_ sender: NSControl) {
        if Preferences.language == .systemDefault {
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        } else {
            UserDefaults.standard.set([Preferences.language.appleLanguageCode!], forKey: "AppleLanguages")
        }
        // Inform the user that the app needs to restart to apply the language change
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = NSLocalizedString("Language Change", comment: "")
        alert.informativeText = NSLocalizedString("The application needs to restart to apply the language change.", comment: "")
        alert.addButton(withTitle: NSLocalizedString("Restart Now", comment: ""))
        alert.addButton(withTitle: NSLocalizedString("Later", comment: ""))
        if alert.runModal() == .alertFirstButtonReturn {
            App.restart()
        }
    }
}
