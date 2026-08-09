import Cocoa

class AppsUrlsTab {
    static func initTab() -> NSView {
        let launchAppsTable = TableGroupView(width: SettingsWindow.contentWidth)
        (0..<Preferences.maxLaunchAppCount).forEach { index in
            launchAppsTable.addRow(makeLaunchAppRow(index))
        }
        let openUrlsTable = TableGroupView(width: SettingsWindow.contentWidth)
        (0..<Preferences.maxOpenUrlCount).forEach { index in
            openUrlsTable.addRow(makeOpenUrlRow(index))
        }
        return TableGroupSetView(originalViews: [launchAppsTable, openUrlsTable], bottomPadding: 0)
    }

    private static func makeLaunchAppRow(_ index: Int) -> TableGroupView.Row {
        let warningLabel = makeWarningLabel()
        let bundleIdField = LabelAndControl.makeTextArea(30, 1, NSLocalizedString("Bundle ID or name", comment: ""), Preferences.indexToName("launchAppBundleIdentifier", index),
                                                           extraAction: { _ in updateWarningLabel(warningLabel, LaunchAppAction.isMisconfigured(index), NSLocalizedString("No installed application matches this bundle identifier or name.", comment: "")) })
        updateWarningLabel(warningLabel, LaunchAppAction.isMisconfigured(index), NSLocalizedString("No installed application matches this bundle identifier or name.", comment: ""))
        let title = String(format: NSLocalizedString("App %d", comment: ""), index + 1)
        let recorderViews = LabelAndControl.makeLabelWithRecorder(title, LaunchAppAction.shortcutPreferenceKey(index), Preferences.shortcut(LaunchAppAction.shortcutPreferenceKey(index)))
        return TableGroupView.Row(leftTitle: title,
                                   rightViews: bundleIdField + [warningLabel, recorderViews[1]])
    }

    private static func makeOpenUrlRow(_ index: Int) -> TableGroupView.Row {
        let warningLabel = makeWarningLabel()
        let urlField = LabelAndControl.makeTextArea(30, 1, NSLocalizedString("URL", comment: ""), Preferences.indexToName("openUrlValue", index),
                                                     extraAction: { _ in updateWarningLabel(warningLabel, OpenUrlAction.isMisconfigured(index), NSLocalizedString("The URL is invalid.", comment: "")) })
        updateWarningLabel(warningLabel, OpenUrlAction.isMisconfigured(index), NSLocalizedString("The URL is invalid.", comment: ""))
        let title = String(format: NSLocalizedString("URL %d", comment: ""), index + 1)
        let recorderViews = LabelAndControl.makeLabelWithRecorder(title, OpenUrlAction.shortcutPreferenceKey(index), Preferences.shortcut(OpenUrlAction.shortcutPreferenceKey(index)))
        return TableGroupView.Row(leftTitle: title,
                                   rightViews: urlField + [warningLabel, recorderViews[1]])
    }

    private static func makeWarningLabel() -> NSTextField {
        let label = NSTextField(labelWithString: "⚠️")
        label.translatesAutoresizingMaskIntoConstraints = false
        label.isHidden = true
        return label
    }

    private static func updateWarningLabel(_ label: NSTextField, _ isMisconfigured: Bool, _ tooltip: String) {
        label.isHidden = !isMisconfigured
        label.toolTip = isMisconfigured ? tooltip : nil
    }
}
