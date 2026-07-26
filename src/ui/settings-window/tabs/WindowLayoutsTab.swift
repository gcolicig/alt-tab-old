import Cocoa

class WindowLayoutsTab {
    static func initTab() -> NSView {
        let table = TableGroupView(width: SettingsWindow.contentWidth)
        WindowLayoutAction.allCases.forEach {
            let views = LabelAndControl.makeLabelWithRecorder($0.localizedTitle, $0.shortcutPreferenceKey, Preferences.shortcut($0.shortcutPreferenceKey))
            table.addRow(TableGroupView.Row(leftTitle: $0.localizedTitle, rightViews: [views[1]]))
        }
        table.addNewTable()
        table.addRow(TableGroupView.Row(
            leftTitle: NSLocalizedString("Use Caps Lock as system-wide Hyper key", comment: ""),
            rightViews: [LabelAndControl.makeSwitch("hyperKeyEnabled")]))
        table.addRow(TableGroupView.Row(
            leftTitle: NSLocalizedString("Tap/hold threshold", comment: ""),
            rightViews: [LabelAndControl.makeDropdown("hyperKeyHoldDuration", HyperKeyHoldDurationPreference.allCases)]))
        table.addRow(hyperKeyActionRow(NSLocalizedString("Left arrow", comment: ""), "hyperKeyLeftAction"))
        table.addRow(hyperKeyActionRow(NSLocalizedString("Right arrow", comment: ""), "hyperKeyRightAction"))
        table.addRow(hyperKeyActionRow(NSLocalizedString("Up arrow", comment: ""), "hyperKeyUpAction"))
        table.addRow(hyperKeyActionRow(NSLocalizedString("Down arrow", comment: ""), "hyperKeyDownAction"))
        return TableGroupSetView(originalViews: [table], bottomPadding: 0)
    }

    private static func hyperKeyActionRow(_ title: String, _ preferenceKey: String) -> TableGroupView.Row {
        TableGroupView.Row(
            leftTitle: title,
            rightViews: [LabelAndControl.makeDropdown(preferenceKey, HyperKeyActionPreference.allCases)])
    }
}
