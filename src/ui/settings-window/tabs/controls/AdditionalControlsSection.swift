import Cocoa

enum AdditionalControlsSection {
    static func makeView() -> NSView {
        let enableArrows = TableGroupView.Row(leftTitle: NSLocalizedString("Select windows using arrow keys", comment: ""),
            rightViews: [LabelAndControl.makeSwitch("arrowKeysEnabled", extraAction: ControlsTab.arrowKeysEnabledCallback)])
        let enableVimKeys = TableGroupView.Row(leftTitle: NSLocalizedString("Select windows using vim keys", comment: ""),
            rightViews: [LabelAndControl.makeSwitch("vimKeysEnabled", extraAction: ControlsTab.vimKeysEnabledCallback)])
        let enableMouse = TableGroupView.Row(leftTitle: NSLocalizedString("Select windows on mouse hover", comment: ""),
            rightViews: [LabelAndControl.makeSwitch("mouseHoverEnabled")])
        let enableCursorFollowFocus = TableGroupView.Row(leftTitle: NSLocalizedString("Cursor follows focus", comment: ""),
            rightViews: [LabelAndControl.makeDropdown("cursorFollowFocus", CursorFollowFocus.allCases)])
        let enableTrackpadHapticFeedback = TableGroupView.Row(leftTitle: NSLocalizedString("Trackpad haptic feedback", comment: ""),
            rightViews: [LabelAndControl.makeSwitch("trackpadHapticFeedbackEnabled")])
        let arrowKeysCheckbox = enableArrows.rightViews[0] as? Switch
        let vimKeysCheckbox = enableVimKeys.rightViews[0] as? Switch
        ControlsTab.arrowKeysCheckbox = arrowKeysCheckbox
        ControlsTab.vimKeysCheckbox = vimKeysCheckbox
        if let arrowKeysCheckbox { ControlsTab.arrowKeysEnabledCallback(arrowKeysCheckbox) }
        if let vimKeysCheckbox { ControlsTab.vimKeysEnabledCallback(vimKeysCheckbox) }
        let table1 = TableGroupView(width: SettingsWindow.width)
        _ = table1.addRow(enableArrows)
        _ = table1.addRow(enableVimKeys)
        _ = table1.addRow(enableMouse)
        let table2 = TableGroupView(title: NSLocalizedString("Miscellaneous", comment: ""),
            width: SettingsWindow.width)
        _ = table2.addRow(enableCursorFollowFocus)
        _ = table2.addRow(enableTrackpadHapticFeedback)
        let view = TableGroupSetView(originalViews: [table1, table2], padding: 0)
        return view
    }
}
