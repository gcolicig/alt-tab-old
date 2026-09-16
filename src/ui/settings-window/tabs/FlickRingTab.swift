import Cocoa

class FlickRingTab {
    static func initTab() -> NSView {
        let table = TableGroupView(width: SettingsWindow.contentWidth)
        table.addRow(TableGroupView.Row(
            leftTitle: NSLocalizedString("Open an action ring on a mouse button", comment: ""),
            rightViews: [LabelAndControl.makeSwitch("flickRingEnabled") { _ in FlickRingEvents.enabledChanged() }]))
        table.addRow(TableGroupView.Row(
            leftTitle: NSLocalizedString("Mouse button", comment: ""),
            subTitle: NSLocalizedString("The chosen button is reserved while the ring is on.", comment: ""),
            rightViews: [makeButtonPopup()]))
        let directions = TableGroupView(width: SettingsWindow.contentWidth)
        FlickDirection.allCases.forEach { direction in
            directions.addRow(TableGroupView.Row(
                leftTitle: title(direction),
                rightViews: [LabelAndControl.makeActionPopup(FlickRingBindingsStore.stableId(for: direction)) { stableId in
                    FlickRingBindingsStore.set(direction, stableId)
                }]))
        }
        return TableGroupSetView(originalViews: [table, directions], bottomPadding: 0)
    }

    private static func makeButtonPopup() -> NSPopUpButton {
        let popup = PopupButtonLikeSystemSettings()
        let options: [(String, Int)] = [
            (NSLocalizedString("Side button (back)", comment: ""), 3),
            (NSLocalizedString("Side button (forward)", comment: ""), 4),
            (NSLocalizedString("Middle button", comment: ""), 2),
        ]
        options.forEach { titleText, number in
            popup.addItem(withTitle: titleText)
            popup.lastItem?.tag = number
        }
        popup.selectItem(withTag: Preferences.flickRingButton)
        popup.identifier = NSUserInterfaceItemIdentifier("flickRingButton")
        popup.onAction = { control in
            let tag = (control as? NSPopUpButton)?.selectedItem?.tag ?? 3
            Preferences.set("flickRingButton", String(tag))
            FlickRingEvents.enabledChanged()
        }
        return popup
    }

    private static func title(_ direction: FlickDirection) -> String {
        switch direction {
            case .up: return NSLocalizedString("Flick up", comment: "")
            case .right: return NSLocalizedString("Flick right", comment: "")
            case .down: return NSLocalizedString("Flick down", comment: "")
            case .left: return NSLocalizedString("Flick left", comment: "")
        }
    }
}
