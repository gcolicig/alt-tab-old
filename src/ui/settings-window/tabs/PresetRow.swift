import Cocoa

/// The settings row that assigns or removes a `ShortcutPreset`.
class PresetRow {
    private static var buttons = [String: NSButton]()

    static func make(_ preset: ShortcutPreset) -> TableGroupView.Row {
        let button = NSButton(title: "", target: self, action: #selector(onClick(_:)))
        button.bezelStyle = .rounded
        button.identifier = NSUserInterfaceItemIdentifier(preset.id)
        buttons[preset.id] = button
        update(preset)
        return TableGroupView.Row(leftTitle: preset.title, subTitle: preset.summary, rightViews: [button])
    }

    /// One active preset per domain, so assigning one disables the others of that domain.
    static func refreshAll() {
        ShortcutPresets.all.forEach { update($0) }
    }

    @objc private static func onClick(_ sender: NSButton) {
        guard let id = sender.identifier?.rawValue,
              let preset = ShortcutPresets.all.first(where: { $0.id == id }) else { return }
        if preset.isActive {
            guard confirmRemoval(preset) else { return }
            preset.remove()
        } else {
            preset.apply()
        }
        refreshAll()
    }

    /// Removing restores the state from before the preset was assigned, which discards anything the
    /// user changed in the meantime. That is worth asking about rather than announcing afterwards.
    private static func confirmRemoval(_ preset: ShortcutPreset) -> Bool {
        guard preset.hasCustomChanges else { return true }
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = NSLocalizedString("Discard your changes to this set?", comment: "")
        alert.informativeText = NSLocalizedString("You changed shortcuts while this set was assigned. Removing it restores the shortcuts you had before it was assigned, so those changes are lost.", comment: "")
        alert.addButton(withTitle: NSLocalizedString("Remove and restore", comment: ""))
        let cancelButton = alert.addButton(withTitle: NSLocalizedString("Cancel", comment: ""))
        cancelButton.keyEquivalent = "\u{1b}"
        return alert.runModal() == .alertFirstButtonReturn
    }

    private static func update(_ preset: ShortcutPreset) {
        guard let button = buttons[preset.id] else { return }
        button.title = preset.isActive
            ? NSLocalizedString("Remove", comment: "")
            : NSLocalizedString("Assign", comment: "")
        button.isEnabled = preset.isActive || ShortcutPresets.isAssignable(preset)
    }
}
