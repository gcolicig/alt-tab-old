import Cocoa

class SpacesTab {
    static func initTab() -> NSView {
        let table = TableGroupView(width: SettingsWindow.contentWidth)
        table.addRow(TableGroupView.Row(
            leftTitle: NSLocalizedString("Show Spaces next to the menubar icon", comment: ""),
            rightViews: [LabelAndControl.makeSwitch("spacesInMenubarShown")]))
        table.addNewTable()
        ShortcutPresets.all.forEach { table.addRow(presetRow($0)) }
        table.addNewTable()
        SpaceAction.all.forEach {
            let views = LabelAndControl.makeLabelWithRecorder($0.localizedTitle, $0.shortcutPreferenceKey, Preferences.shortcut($0.shortcutPreferenceKey))
            table.addRow(TableGroupView.Row(leftTitle: $0.localizedTitle, rightViews: [views[1]]))
        }
        return TableGroupSetView(originalViews: [table], bottomPadding: 0)
    }

    private static var presetButtons = [String: NSButton]()

    private static func presetRow(_ preset: ShortcutPreset) -> TableGroupView.Row {
        let button = NSButton(title: "", target: self, action: #selector(presetButtonOnClick(_:)))
        button.bezelStyle = .rounded
        button.identifier = NSUserInterfaceItemIdentifier(preset.id)
        presetButtons[preset.id] = button
        updatePresetButton(preset)
        return TableGroupView.Row(leftTitle: preset.title, subTitle: preset.summary, rightViews: [button])
    }

    @objc private static func presetButtonOnClick(_ sender: NSButton) {
        guard let id = sender.identifier?.rawValue,
              let preset = ShortcutPresets.all.first(where: { $0.id == id }) else { return }
        if preset.isApplied {
            preset.remove()
        } else {
            let conflicts = preset.conflicts()
            preset.apply()
            if !conflicts.isEmpty {
                // the user assigned these themselves, so they keep them; only say what was left out
                TransientNotice.show(String(format: NSLocalizedString("%d shortcuts of this set were kept as you assigned them and not replaced.", comment: ""), conflicts.count))
            }
        }
        updatePresetButton(preset)
    }

    private static func updatePresetButton(_ preset: ShortcutPreset) {
        presetButtons[preset.id]?.title = preset.isApplied
            ? NSLocalizedString("Remove", comment: "")
            : NSLocalizedString("Assign", comment: "")
    }
}
