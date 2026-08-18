import Cocoa

/// Project profiles: name, apps, optional layout, optional bound space, optional shortcut. Stage one only —
/// activation switches the bound space and filters the switcher to the profile's apps. Nothing is started,
/// quit, hidden, or moved.
class ProfilesTab {
    private static var bindingLabels = [Int: NSTextField]()

    static func initTab() -> NSView {
        bindingLabels.removeAll()
        let tables = (0..<Preferences.maxProfileCount).map { makeProfileTable($0) }
        return TableGroupSetView(originalViews: tables, bottomPadding: 0)
    }

    private static func makeProfileTable(_ index: Int) -> TableGroupView {
        let table = TableGroupView(title: String(format: NSLocalizedString("Profile %d", comment: ""), index + 1),
                                   width: SettingsWindow.contentWidth)
        let name = LabelAndControl.makeTextArea(24, 1, NSLocalizedString("Name", comment: ""), ProfileStore.nameKey(index))
        table.addRow(TableGroupView.Row(leftTitle: NSLocalizedString("Name", comment: ""), rightViews: name))
        let apps = LabelAndControl.makeTextArea(24, 3, NSLocalizedString("Bundle IDs, one per line", comment: ""), ProfileStore.appsKey(index))
        table.addRow(TableGroupView.Row(leftTitle: NSLocalizedString("Apps", comment: ""),
                                        subTitle: NSLocalizedString("Only these apps show while the profile is active.", comment: ""),
                                        rightViews: apps))
        table.addRow(TableGroupView.Row(leftTitle: NSLocalizedString("Layout", comment: ""), rightViews: [makeLayoutPopup(index)]))
        table.addRow(TableGroupView.Row(leftTitle: NSLocalizedString("Bound space", comment: ""),
                                        subTitle: NSLocalizedString("A lost binding is shown, never repointed.", comment: ""),
                                        rightViews: makeBindingViews(index)))
        let recorder = LabelAndControl.makeLabelWithRecorder(NSLocalizedString("Shortcut", comment: ""),
                                                             ProfileStore.shortcutPreferenceKey(index),
                                                             Preferences.shortcut(ProfileStore.shortcutPreferenceKey(index)))
        table.addRow(TableGroupView.Row(leftTitle: NSLocalizedString("Shortcut", comment: ""), rightViews: [recorder[1]]))
        return table
    }

    private static func makeLayoutPopup(_ index: Int) -> NSPopUpButton {
        let popup = PopupButtonLikeSystemSettings()
        popup.addItem(withTitle: NSLocalizedString("None", comment: ""))
        popup.lastItem?.representedObject = ""
        let current = CachedUserDefaults.string(ProfileStore.layoutKey(index))
        var selected = 0
        for (offset, action) in WindowLayoutAction.allCases.filter({ $0 != .restore }).enumerated() {
            popup.addItem(withTitle: action.localizedTitle)
            popup.lastItem?.representedObject = action.rawValue
            if action.rawValue == current { selected = offset + 1 }
        }
        popup.selectItem(at: selected)
        popup.onAction = { control in
            let raw = (control as? NSPopUpButton)?.selectedItem?.representedObject as? String ?? ""
            Preferences.set(ProfileStore.layoutKey(index), raw)
        }
        return popup
    }

    private static func makeBindingViews(_ index: Int) -> [NSView] {
        let label = NSTextField(labelWithString: "")
        label.translatesAutoresizingMaskIntoConstraints = false
        bindingLabels[index] = label
        updateBindingLabel(index)
        let bind = NSButton(title: NSLocalizedString("Bind to current space", comment: ""), target: nil, action: nil)
        bind.onAction = { _ in
            Preferences.set(ProfileStore.spaceUuidKey(index), Spaces.currentSpaceUuid ?? "")
            updateBindingLabel(index)
        }
        let clear = NSButton(title: NSLocalizedString("Clear", comment: ""), target: nil, action: nil)
        clear.onAction = { _ in
            Preferences.set(ProfileStore.spaceUuidKey(index), "")
            updateBindingLabel(index)
        }
        return [label, bind, clear]
    }

    private static func updateBindingLabel(_ index: Int) {
        guard let label = bindingLabels[index] else { return }
        let uuid = CachedUserDefaults.string(ProfileStore.spaceUuidKey(index))
        if uuid.isEmpty {
            label.stringValue = NSLocalizedString("Not bound", comment: "")
            label.textColor = .secondaryLabelColor
        } else if SpaceIdentity.isPresent(uuid, in: Spaces.identitySnapshot()) {
            label.stringValue = NSLocalizedString("Bound", comment: "")
            label.textColor = .secondaryLabelColor
        } else {
            label.stringValue = NSLocalizedString("Bound space is gone", comment: "")
            label.textColor = .systemOrange
        }
    }
}
