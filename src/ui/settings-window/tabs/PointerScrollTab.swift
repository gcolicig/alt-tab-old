import Cocoa

class PointerScrollTab {
    /// The rows are built once, but ownership can change while the window is closed — another tool takes
    /// the value, or a crash recovery relinquishes it. Without this the tab would keep claiming
    /// "Managed by AltTab+" indefinitely, the same silent lie safe mode used to tell about the drag module.
    private static var ownershipLabels = [PointerCategory: NSTextField]()

    static func refreshControlsFromPreferences() {
        PointerCategory.allCases.forEach { ownershipLabels[$0]?.stringValue = ownershipDescription($0) }
    }

    static func initTab() -> NSView {
        let table = TableGroupView(width: SettingsWindow.contentWidth)
        addCategory(table, .mouse, NSLocalizedString("Mouse pointer acceleration", comment: ""), NSLocalizedString("Mouse pointer speed", comment: ""))
        table.addNewTable()
        addCategory(table, .trackpad, NSLocalizedString("Trackpad pointer acceleration", comment: ""), NSLocalizedString("Trackpad pointer speed", comment: ""))
        return TableGroupSetView(originalViews: [table], bottomPadding: 0)
    }

    private static func addCategory(_ table: TableGroupView, _ category: PointerCategory, _ accelerationTitle: String, _ speedTitle: String) {
        let accelerationKey = category == .mouse ? "pointerMouseAcceleration" : "pointerTrackpadAcceleration"
        let speedKey = category == .mouse ? "pointerMouseSpeed" : "pointerTrackpadSpeed"
        let ownership = LabelAndControl.makeLabel(ownershipDescription(category))
        ownershipLabels[category] = ownership
        table.addRow(TableGroupView.Row(
            leftTitle: accelerationTitle,
            rightViews: [LabelAndControl.makeDropdown(accelerationKey, PointerAccelerationPreference.allCases) { _ in
                apply(category)
                refreshControlsFromPreferences()
            }]))
        table.addRow(TableGroupView.Row(leftTitle: NSLocalizedString("Ownership", comment: ""), rightViews: [ownership]))
        let slider = LabelAndControl.makeLabelWithSlider(speedTitle, speedKey, 0, Double(PointerSpeedSteps.maximumIndex), PointerSpeedSteps.values.count, true, "") { _ in apply(category) }
        table.addRow(TableGroupView.Row(leftTitle: speedTitle, rightViews: [slider[1]]))
    }

    /// The dropdown is the only deliberate activation there is: moving off `System default` acquires the
    /// value, moving back to it hands it back. A speed change never acquires on its own.
    static func apply(_ category: PointerCategory) {
        guard let desired = Preferences.pointerDesiredValue(category) else {
            PointerOwnership.release(category)
            return
        }
        if PointerOwnership.state(category) == .managed {
            PointerOwnership.update(category, desired: desired)
        } else {
            PointerOwnership.acquire(category, desired: desired)
        }
    }

    private static func ownershipDescription(_ category: PointerCategory) -> String {
        switch PointerOwnership.state(category) {
            case .unmanaged: return NSLocalizedString("Not managed by AltTab+", comment: "")
            case .managed: return NSLocalizedString("Managed by AltTab+", comment: "")
            // deliberately neutral: another tool or System Settings owning this value is not a user error
            case .relinquished: return NSLocalizedString("Changed outside AltTab+; pick a mode again to take it over", comment: "")
        }
    }
}
