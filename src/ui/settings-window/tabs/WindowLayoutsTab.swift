import Cocoa

class WindowLayoutsTab {
    static func initTab() -> NSView {
        let table = TableGroupView(width: SettingsWindow.contentWidth)
        table.addRow(TableGroupView.Row(
            leftTitle: NSLocalizedString("Move the window under the cursor while holding", comment: ""),
            subTitle: NSLocalizedString("Off by default. Every candidate collides with something, so pick one knowingly.", comment: ""),
            rightViews: [LabelAndControl.makeDropdown("windowDragModifier", DragModifierPreference.selectable) { _ in WindowDragEvents.modifierPreferenceChanged(announceSuppression: true) }]))
        table.addNewTable()
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
            rightViews: [LabelAndControl.makeSwitch("inputModulesSafeMode") { _ in safeModeChanged() }]))
        return TableGroupSetView(originalViews: [table], bottomPadding: 0)
    }

    /// Leaving safe mode has to rebuild the tap of an already chosen modifier. Without this the dropdown
    /// keeps showing a modifier that does nothing until the next launch.
    private static func safeModeChanged() {
        KeyboardEvents.inputSafeModeChanged()
        WindowDragEvents.modifierPreferenceChanged()
    }
}
