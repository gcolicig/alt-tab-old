import Cocoa

/// The settings row that assigns or removes a `ShortcutPreset`.
class PresetRow {
    private static var buttons = [String: NSButton]()

    static func make(_ preset: ShortcutPreset) -> TableGroupView.Row {
        let button = NSButton(title: "", target: self, action: #selector(onClick(_:)))
        button.bezelStyle = .rounded
        button.identifier = NSUserInterfaceItemIdentifier(preset.id)
        buttons[preset.id] = button
        updateTitle(preset)
        return TableGroupView.Row(leftTitle: preset.title, subTitle: preset.summary, rightViews: [button])
    }

    /// Presets share preference keys, so applying one can make another partially assigned.
    static func refreshAll() {
        ShortcutPresets.all.forEach { updateTitle($0) }
    }

    @objc private static func onClick(_ sender: NSButton) {
        guard let id = sender.identifier?.rawValue,
              let preset = ShortcutPresets.all.first(where: { $0.id == id }) else { return }
        if preset.isApplied {
            preset.remove()
        } else {
            let occupied = preset.occupiedKeys()
            preset.apply()
            if !occupied.isEmpty {
                // the user assigned these themselves, so they keep them; only say what was left out
                TransientNotice.show(String(format: NSLocalizedString("%d shortcuts of this set were kept as you assigned them and not replaced.", comment: ""), occupied.count))
            }
        }
        refreshAll()
    }

    private static func updateTitle(_ preset: ShortcutPreset) {
        buttons[preset.id]?.title = preset.isApplied
            ? NSLocalizedString("Remove", comment: "")
            : NSLocalizedString("Assign", comment: "")
    }
}
