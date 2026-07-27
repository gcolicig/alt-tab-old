import Cocoa

class SpacesTab {
    static func initTab() -> NSView {
        let table = TableGroupView(width: SettingsWindow.contentWidth)
        table.addRow(TableGroupView.Row(
            leftTitle: NSLocalizedString("Show Spaces next to the menubar icon", comment: ""),
            rightViews: [LabelAndControl.makeSwitch("spacesInMenubarShown")]))
        table.addNewTable()
        SpaceAction.all.forEach {
            let views = LabelAndControl.makeLabelWithRecorder($0.localizedTitle, $0.shortcutPreferenceKey, Preferences.shortcut($0.shortcutPreferenceKey))
            table.addRow(TableGroupView.Row(leftTitle: $0.localizedTitle, rightViews: [views[1]]))
        }
        return TableGroupSetView(originalViews: [table], bottomPadding: 0)
    }
}
