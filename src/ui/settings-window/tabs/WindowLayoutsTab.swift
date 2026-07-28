import Cocoa

class WindowLayoutsTab {
    static func initTab() -> NSView {
        let table = TableGroupView(width: SettingsWindow.contentWidth)
        ShortcutPresets.layouts.forEach { table.addRow(PresetRow.make($0)) }
        table.addNewTable()
        WindowLayoutAction.allCases.forEach {
            let views = LabelAndControl.makeLabelWithRecorder($0.localizedTitle, $0.shortcutPreferenceKey, Preferences.shortcut($0.shortcutPreferenceKey))
            table.addRow(TableGroupView.Row(leftTitle: $0.localizedTitle, rightViews: [views[1]]))
        }
        table.addNewTable()
        DisplayMoveAction.allCases.forEach {
            let views = LabelAndControl.makeLabelWithRecorder($0.localizedTitle, $0.shortcutPreferenceKey, Preferences.shortcut($0.shortcutPreferenceKey))
            table.addRow(TableGroupView.Row(leftTitle: $0.localizedTitle, rightViews: [views[1]]))
        }
        table.addNewTable()
        table.addRow(TableGroupView.Row(
            leftTitle: NSLocalizedString("Disable input extensions (safe mode)", comment: ""),
            rightViews: [LabelAndControl.makeSwitch("inputModulesSafeMode")]))
        return TableGroupSetView(originalViews: [table], bottomPadding: 0)
    }
}
