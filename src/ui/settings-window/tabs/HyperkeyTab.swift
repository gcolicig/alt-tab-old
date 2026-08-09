import Cocoa

class HyperkeyTab {
    static func initTab() -> NSView {
        let table = TableGroupView(width: SettingsWindow.contentWidth)
        table.addRow(TableGroupView.Row(
            leftTitle: NSLocalizedString("Use Caps Lock as system-wide Hyper key", comment: ""),
            rightViews: [LabelAndControl.makeSwitch("hyperKeyEnabled")]))
        table.addRow(TableGroupView.Row(
            leftTitle: NSLocalizedString("Tap/hold threshold", comment: ""),
            rightViews: [LabelAndControl.makeDropdown("hyperKeyHoldDuration", HyperKeyHoldDurationPreference.allCases)]))
        return TableGroupSetView(originalViews: [table], bottomPadding: 0)
    }
}
