import Cocoa

class WindowLayoutsTab {
    static func initTab() -> NSView {
        let table = TableGroupView(width: SettingsWindow.contentWidth)
        table.addRow(TableGroupView.Row(
            leftTitle: NSLocalizedString("Move the window under the cursor while holding", comment: ""),
            subTitle: NSLocalizedString("Off by default. Every candidate collides with something, so pick one knowingly.", comment: ""),
            rightViews: [LabelAndControl.makeDropdown("windowDragModifier", DragModifierPreference.selectable) { _ in modifierChanged(resize: false) }]))
        table.addRow(TableGroupView.Row(
            leftTitle: NSLocalizedString("Resize the window under the cursor while holding", comment: ""),
            subTitle: NSLocalizedString("The corner you start near is the one that follows; the opposite corner stays put.", comment: ""),
            rightViews: [LabelAndControl.makeDropdown("windowResizeModifier", DragModifierPreference.selectable) { _ in modifierChanged(resize: true) }]))
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
        let cluesViews = LabelAndControl.makeLabelWithRecorder(NSLocalizedString("Show the active app's shortcuts while holding", comment: ""),
                                                              ShortcutCluesController.shortcutPreferenceKey,
                                                              Preferences.shortcut(ShortcutCluesController.shortcutPreferenceKey))
        table.addRow(TableGroupView.Row(
            leftTitle: NSLocalizedString("Show the active app's shortcuts while holding", comment: ""),
            subTitle: NSLocalizedString("Reads the menus of the app in front. It never absorbs keys, so a shortcut you press while looking still runs.", comment: ""),
            rightViews: [cluesViews[1]]))
        table.addNewTable()
        table.addRow(TableGroupView.Row(
            leftTitle: NSLocalizedString("Disable input extensions (safe mode)", comment: ""),
            rightViews: [LabelAndControl.makeSwitch("inputModulesSafeMode") { _ in safeModeChanged() }]))
        return TableGroupSetView(originalViews: [table], bottomPadding: 0)
    }

    /// Both modules share one tap and one session, so the same combination cannot drive both: whichever
    /// module was just changed gives way, and says why rather than silently doing nothing.
    private static func modifierChanged(resize: Bool) {
        if DragModeSelection.conflict(move: Preferences.windowDragModifier, resize: Preferences.windowResizeModifier) {
            Preferences.set(resize ? "windowResizeModifier" : "windowDragModifier", "0", false)
            TransientNotice.show(NSLocalizedString("Moving and resizing cannot use the same modifier.", comment: ""))
        }
        WindowDragEvents.modifierPreferenceChanged(announceSuppression: true)
    }

    /// Leaving safe mode has to rebuild the tap of an already chosen modifier. Without this the dropdown
    /// keeps showing a modifier that does nothing until the next launch.
    private static func safeModeChanged() {
        KeyboardEvents.inputSafeModeChanged()
        WindowDragEvents.modifierPreferenceChanged()
    }
}
