import Cocoa

class LeaderTab {
    private static var warningLabel: NSTextField?

    static func initTab() -> NSView {
        let warning = makeWarningLabel()
        warningLabel = warning

        let top = TableGroupView(width: SettingsWindow.contentWidth)
        top.addRow(TableGroupView.Row(
            leftTitle: NSLocalizedString("Enable Leader sequences", comment: ""),
            rightViews: [LabelAndControl.makeSwitch("leaderEnabled") { _ in LeaderController.rebuildTrie() }]))
        let recorder = LabelAndControl.makeLabelWithRecorder(
            NSLocalizedString("Trigger key", comment: ""),
            LeaderController.triggerPreferenceKey,
            Preferences.shortcut(LeaderController.triggerPreferenceKey))
        top.addRow(TableGroupView.Row(
            leftTitle: NSLocalizedString("Trigger key", comment: ""),
            subTitle: NSLocalizedString("Press this, then a sequence of keys.", comment: ""),
            rightViews: [recorder[1]]))

        let slots = TableGroupView(width: SettingsWindow.contentWidth)
        (0..<Preferences.maxLeaderSlotCount).forEach { slot in
            slots.addRow(makeSlotRow(slot))
        }
        slots.addRow(TableGroupView.Row(
            leftTitle: NSLocalizedString("Sequences use letters and digits, e.g. \"wl\". Escape and timeout cancel.", comment: ""),
            rightViews: [warning]))
        return TableGroupSetView(originalViews: [top, slots], padding: 0, bottomPadding: 0)
    }

    private static func makeSlotRow(_ slot: Int) -> TableGroupView.Row {
        let keysField = LabelAndControl.makeTextArea(10, 1, NSLocalizedString("keys", comment: ""),
                                                     LeaderBindingsStore.keysPreferenceKey(slot),
                                                     extraAction: { _ in changed() })
        let actionPopup = LabelAndControl.makeActionPopup(CachedUserDefaults.string(LeaderBindingsStore.actionPreferenceKey(slot))) { stableId in
            Preferences.set(LeaderBindingsStore.actionPreferenceKey(slot), stableId ?? "")
            changed()
        }
        return TableGroupView.Row(leftTitle: String(format: NSLocalizedString("Sequence %d", comment: ""), slot + 1),
                                  rightViews: keysField + [actionPopup])
    }

    private static func changed() {
        LeaderController.rebuildTrie()
        updateWarning()
    }

    private static func updateWarning() {
        guard let warningLabel else { return }
        let message = LeaderBindingsStore.validationMessage()
        warningLabel.stringValue = message ?? ""
        warningLabel.isHidden = message == nil
    }

    private static func makeWarningLabel() -> NSTextField {
        let label = NSTextField(labelWithString: "")
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textColor = .systemOrange
        label.isHidden = true
        return label
    }
}
