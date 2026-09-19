import Cocoa
import Carbon.HIToolbox.Events
import ShortcutRecorder

/// Story 16: `Record Shortcut` did not fit and showed as `Recor…rtcut`.
/// Also matches the "None" wording used by the read-only overview page (ShortcutOverviewTab).
final class ShortPlaceholderStyle: RecorderControlStyle {
    override var noValueNormalLabel: String {
        NSLocalizedString("None", comment: "Placeholder of an empty shortcut recorder")
    }
}

class CustomRecorderControl: RecorderControl {
    static let allowedModifiers = NSEvent.ModifierFlags(arrayLiteral: [.command, .control, .option, .shift])
    var clearable: Bool!
    var id: String!
    /// Tracks mouse-hover to draw the subtle background used by the overview-style recorder;
    /// the pod itself only draws a background bezel, no plain hover state.
    private var isHoveredControl = false
    private var hoverTrackingArea: NSTrackingArea?
    /// Notified whenever this control's `objectValue` changes through a programmatic path (e.g.
    /// `updateShortcut`, used when accepting a conflict clears another recorder) rather than through
    /// `onAction`. Lets callers like the "Restore default" button keep their own UI (e.g. its visibility)
    /// in sync even when the change did not originate from this control's own recording gesture.
    var onProgrammaticChange: (() -> Void)?

    convenience init(_ shortcutString: String, _ clearable: Bool, _ id: String) {
        self.init(Shortcut(keyEquivalent: shortcutString), clearable, id)
    }

    convenience init(_ shortcut: Shortcut?, _ clearable: Bool, _ id: String) {
        self.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        self.clearable = clearable
        self.id = id
        delegate = self
        allowsEscapeToCancelRecording = false
        allowsDeleteToClearShortcutAndEndRecording = false
        allowsModifierFlagsOnlyShortcut = true
        restrictModifiers([])
        objectValue = shortcut
        style = ShortPlaceholderStyle(identifier: nil, components: nil)
        addOrUpdateConstraint(widthAnchor, 130)
    }

    override func drawClearButton(_ aDirtyRect: NSRect) {
        if clearable {
            super.drawClearButton(aDirtyRect)
        }
    }

    /// Renders as plain text like the read-only Shortcuts overview page: no grey filled bar in the
    /// normal state. The bezel is kept only while recording, since it is the recording indicator.
    override func drawBackground(_ aDirtyRect: NSRect) {
        if isRecording {
            super.drawBackground(aDirtyRect)
            return
        }
        if isHoveredControl {
            NSColor.quaternaryLabelColor.setFill()
            NSBezierPath(roundedRect: bounds, xRadius: 5, yRadius: 5).fill()
        }
    }

    /// Same label color rule as ShortcutOverviewTab.shortcutLabel: tertiary when empty, label color
    /// when a shortcut is assigned. normalLabelAttributes/disabledLabelAttributes still supply the
    /// font and paragraph style (centered; the pod's alignment guides don't support right-alignment
    /// without reimplementing layout, so this keeps the existing centered text).
    override var drawingLabelAttributes: [NSAttributedString.Key: Any]? {
        guard var attributes = super.drawingLabelAttributes else { return nil }
        if isEnabled && !isRecording {
            let isEmpty = objectValue == nil
            attributes[.foregroundColor] = isEmpty ? NSColor.tertiaryLabelColor : NSColor.labelColor
        }
        return attributes
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let hoverTrackingArea {
            removeTrackingArea(hoverTrackingArea)
        }
        let trackingArea = NSTrackingArea(rect: bounds,
                                           options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
                                           owner: self, userInfo: nil)
        addTrackingArea(trackingArea)
        hoverTrackingArea = trackingArea
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        isHoveredControl = true
        needsDisplay = true
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        isHoveredControl = false
        needsDisplay = true
    }

    override func clearAndEndRecording() {
        if clearable {
            super.clearAndEndRecording()
        }
    }

    func restrictModifiers(_ restrictedModifiers: NSEvent.ModifierFlags) {
        set(allowedModifierFlags: CustomRecorderControl.allowedModifiers.subtracting(restrictedModifiers), requiredModifierFlags: [], allowsEmptyModifierFlags: true)
    }

    func alertIfSameShortcutAlreadyAssigned(_ candidateShortcut: Shortcut, _ shortcutAlreadyAssigned: String) {
        let isArrowKeys = ["←", "→", "↑", "↓"].contains(shortcutAlreadyAssigned)
        let isVimKeys = shortcutAlreadyAssigned.starts(with: "vimCycle")
        let existingShortcut = ControlsTab.shortcutControls[shortcutAlreadyAssigned]
        let existingShortcutLabel = isArrowKeys ? "Arrow keys" : (isVimKeys ? "Vim keys" : existingShortcut?.1 ?? shortcutAlreadyAssigned)
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = NSLocalizedString("Conflicting shortcut", comment: "")
        alert.informativeText = String(format: NSLocalizedString("Shortcut already assigned to another action: %@", comment: ""),
                                       existingShortcutLabel.replacingOccurrences(of: " ", with: "\u{00A0}"))
        if !id.starts(with: "holdShortcut") {
            alert.addButton(withTitle: NSLocalizedString("Unassign existing shortcut and continue", comment: "")).setAccessibilityFocused(true)
        }
        let cancelButton = alert.addButton(withTitle: NSLocalizedString("Cancel", comment: ""))
        cancelButton.keyEquivalent = "\u{1b}"
        if id.starts(with: "holdShortcut") {
            cancelButton.setAccessibilityFocused(true)
        }
        let userChoice = alert.runModal()
        if !id.starts(with: "holdShortcut") && userChoice == .alertFirstButtonReturn {
            if isArrowKeys {
                ControlsTab.arrowKeysCheckbox.state = .off
                ControlsTab.arrowKeysEnabledCallback(ControlsTab.arrowKeysCheckbox)
                LabelAndControl.controlWasChanged(ControlsTab.arrowKeysCheckbox, nil)
            } else if isVimKeys {
                ControlsTab.vimKeysCheckbox.state = .off
                ControlsTab.vimKeysEnabledCallback(ControlsTab.vimKeysCheckbox)
                LabelAndControl.controlWasChanged(ControlsTab.vimKeysCheckbox, nil)
            } else if let existingShortcut {
                updateShortcut(existingShortcut.0, nil, existingShortcut.0, shortcutAlreadyAssigned)
            } else {
                return
            }
            updateShortcut(ControlsTab.shortcutControls[id]!.0, candidateShortcut, self, id)
        }
    }

    func updateShortcut(_ control: CustomRecorderControl, _ objectValue: Shortcut?, _ senderControl: NSControl, _ id: String) {
        control.objectValue = objectValue
        LabelAndControl.controlWasChanged(senderControl, id)
        ControlsTab.shortcutChangedCallback(senderControl)
        // This bypasses `control`'s own `onAction`, so its extraAction (e.g. "Restore default"
        // visibility) never runs on its own; notify it explicitly instead.
        control.onProgrammaticChange?()
    }

    func alertIfShortcutReservedByMacos(_ candidateShortcut: Shortcut, _ shortcutReservedByMacos: String) {
        let existingShortcutLabel = ControlsTab.shortcutControls[shortcutReservedByMacos]!.1
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = NSLocalizedString("Conflicting shortcut", comment: "")
        alert.informativeText = String(format: NSLocalizedString("The ⎋ (escape) key is reserved by some macOS shortcuts (e.g. ⌘⌥⎋ will show the Force Quit Applications window).\n\nYour change would assign it to: %@.\n\nIf you want to use ⎋, make sure that Hold modifiers are neither: ⌘⌥, ⌘⌥⇧, or ⌘⌥⇧⌃", comment: ""), existingShortcutLabel)
        alert.addButton(withTitle: NSLocalizedString("Unassign existing shortcut and continue", comment: ""))
        let cancelButton = alert.addButton(withTitle: NSLocalizedString("Cancel", comment: ""))
        cancelButton.keyEquivalent = "\u{1b}"
        cancelButton.setAccessibilityFocused(true)
        let userChoice = alert.runModal()
        if userChoice == .alertFirstButtonReturn {
            guard id != shortcutReservedByMacos else { return }
            let existingShortcut = ControlsTab.shortcutControls[shortcutReservedByMacos]!
            updateShortcut(existingShortcut.0, nil, existingShortcut.0, shortcutReservedByMacos)
            updateShortcut(ControlsTab.shortcutControls[id]!.0, candidateShortcut, self, id)
        }
    }

    // @available(macOS 26.0, *)
    func alertIfShortcutUsedByGameOverlay(_ candidateShortcut: Shortcut, _ shortcutUsingGameOverlay: String) {
        let existingShortcutLabel = ControlsTab.shortcutControls[shortcutUsingGameOverlay]!.1
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = NSLocalizedString("Conflicting shortcut", comment: "")
        alert.informativeText = String(format: NSLocalizedString("The ⌘⎋ (command+escape) shortcut may be used by macOS for GameOverlay.\n\nYour change would assign it to: %@.\n\nIf you want to continue, make sure that the GameOverlay shortcut is disabled.\nAlso note that macOS has reported bugs where the shortcut may still interfere while disabled.", comment: ""), existingShortcutLabel)
        alert.addButton(withTitle: NSLocalizedString("Open System Settings to confirm, and continue", comment: ""))
        let cancelButton = alert.addButton(withTitle: NSLocalizedString("Cancel", comment: ""))
        cancelButton.keyEquivalent = "\u{1b}"
        cancelButton.setAccessibilityFocused(true)
        let userChoice = alert.runModal()
        if userChoice == .alertFirstButtonReturn {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.keyboard?Shortcuts")!)
            updateShortcut(ControlsTab.shortcutControls[id]!.0, candidateShortcut, self, id)
        }
    }

    func save(_ candidateShortcut: Shortcut) {
        LabelAndControl.controlWasChanged(self, id)
        // shortcutChangedCallback is called automatically here
        // setting objectValue also happens automatically
    }
}

extension CustomRecorderControl: RecorderControlDelegate {
    func recorderControl(_ control: RecorderControl, canRecord shortcut: Shortcut) -> Bool {
        switch CustomRecorderControlTestable.isShortcutAcceptable(id, shortcut) {
        case .accepted: save(shortcut)
        case .modifiersOnlyButContainsKeycode: return false
        case .conflictWithExistingShortcut(let s): alertIfSameShortcutAlreadyAssigned(shortcut, s)
        case .reservedByMacos(let s): alertIfShortcutReservedByMacos(shortcut, s)
        case .usedByGameOverlay(let s): alertIfShortcutUsedByGameOverlay(shortcut, s)
        }
        return true
    }
}
