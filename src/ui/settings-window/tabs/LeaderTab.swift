import Cocoa

class LeaderTab {
    private static var warningLabel: NSTextField?
    /// All slots share the same action list, so the widest item only needs measuring once; every popup is
    /// then pinned to it so the column stays aligned regardless of which action a slot has picked.
    private static var cachedActionPopupWidth: CGFloat?

    static func initTab() -> NSView {
        let warning = makeWarningLabel()
        warningLabel = warning
        // Recomputed per tab build: the registry (e.g. default-browser actions) can change between opens.
        cachedActionPopupWidth = nil

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

        // Added to `top` itself (instead of a second TableGroupView) so the two tables get the normal
        // inter-table gap; two separate TableGroupViews next to each other get no gap at all.
        top.addNewTable()
        (0..<Preferences.maxLeaderSlotCount).forEach { slot in
            top.addRow(makeSlotRow(slot))
        }

        let hint = LabelAndControl.makeDependencyNote(
            NSLocalizedString("Sequences use letters and digits, e.g. \"wl\". Escape and timeout cancel.", comment: ""))
        hint.isHidden = false
        hint.preferredMaxLayoutWidth = SettingsWindow.contentWidth - 2 * TableGroupView.padding

        // One vertical stack, so TableGroupSetView does not put the hint and the warning side by side.
        let notes = StackView([hint, warning], .vertical)
        notes.alignment = .leading
        return TableGroupSetView(originalViews: [top, notes], padding: 0, bottomPadding: 0)
    }

    private static func makeSlotRow(_ slot: Int) -> TableGroupView.Row {
        let keysField = LabelAndControl.makeTextArea(10, 1, NSLocalizedString("keys", comment: ""),
                                                     LeaderBindingsStore.keysPreferenceKey(slot),
                                                     extraAction: { _ in changed() })
        keysField.forEach {
            $0.setContentHuggingPriority(.required, for: .horizontal)
            $0.setContentCompressionResistancePriority(.required, for: .horizontal)
        }
        let actionPopup = LabelAndControl.makeActionPopup(CachedUserDefaults.string(LeaderBindingsStore.actionPreferenceKey(slot))) { stableId in
            Preferences.set(LeaderBindingsStore.actionPreferenceKey(slot), stableId ?? "")
            changed()
        }
        fixActionPopupWidth(actionPopup)
        return TableGroupView.Row(leftTitle: String(format: NSLocalizedString("Sequence %d", comment: ""), slot + 1),
                                  rightViews: keysField + [actionPopup])
    }

    /// `PopupButtonLikeSystemSettings.intrinsicContentSize` is measured from the currently selected item's
    /// title, so two slots with different actions assigned naturally get different popup widths. That made
    /// the whole right-hand column (anchored to the row's trailing edge) jump left or right per slot. Pinning
    /// every popup to the widest title's width keeps the column, and the key field before it, aligned.
    private static func fixActionPopupWidth(_ popup: NSPopUpButton) {
        let selectedIndex = popup.indexOfSelectedItem
        let width = cachedActionPopupWidth ?? measureWidestItemWidth(popup)
        cachedActionPopupWidth = width
        popup.selectItem(at: selectedIndex)
        popup.setContentHuggingPriority(.required, for: .horizontal)
        popup.widthAnchor.constraint(equalToConstant: width).isActive = true
    }

    private static func measureWidestItemWidth(_ popup: NSPopUpButton) -> CGFloat {
        var maxWidth = CGFloat(0)
        for index in 0..<popup.numberOfItems {
            popup.selectItem(at: index)
            maxWidth = max(maxWidth, popup.intrinsicContentSize.width)
        }
        return maxWidth
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
