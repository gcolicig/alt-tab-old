import Cocoa
import ShortcutRecorder

enum LabelPosition {
    case leftWithSeparator
    case leftWithoutSeparator
    case right
}

typealias EventClosure = (NSEvent, NSView) -> Void

class MouseHoverView: NSView {
    var onMouseEntered: EventClosure?
    var onMouseExited: EventClosure?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for trackingArea in trackingAreas {
            removeTrackingArea(trackingArea)
        }
        let newTrackingArea = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways], owner: self, userInfo: nil)
        addTrackingArea(newTrackingArea)
    }

    override func mouseEntered(with event: NSEvent) {
        onMouseEntered?(event, self)
    }

    override func mouseExited(with event: NSEvent) {
        onMouseExited?(event, self)
    }
}

class ClickHoverImageView: MouseHoverView {
    var infoCircle: NSView!
    var onClick: EventClosure?
    var searchableStrings = [String]()

    init(infoCircle: NSView) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        self.infoCircle = infoCircle
        addSubview(infoCircle)
        let clickGesture = NSClickGestureRecognizer(target: self, action: #selector(handleClick(_:)))
        addGestureRecognizer(clickGesture)
    }

    required init?(coder: NSCoder) {
        fatalError("Class only supports programmatic initialization")
    }

    @objc private func handleClick(_ sender: NSClickGestureRecognizer) {
        if let event = sender.view?.window?.currentEvent {
            onClick?(event, self)
        }
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }
}

class LabelAndControl: NSObject {
    // periphery:ignore
    static func makeLabelWithImageRadioButtons(_ labelText: String,
                                               _ rawName: String,
                                               _ macroPreferences: [ImageMacroPreference],
                                               extraAction: ActionClosure? = nil,
                                               buttonSpacing: CGFloat = 15) -> [NSView] {
        let view = makeImageRadioButtons(rawName, macroPreferences, extraAction: extraAction, buttonSpacing: buttonSpacing)
        return [makeLabel(labelText), view]
    }

    static func makeImageRadioButtons(_ rawName: String,
                                      _ macroPreferences: [ImageMacroPreference],
                                      extraAction: ActionClosure? = nil,
                                      buttonSpacing: CGFloat = 15) -> NSStackView {
        var buttons = [ImageTextButtonView]()
        let buttonViews = macroPreferences.enumerated().map { (index, preference) -> ImageTextButtonView in
            let state: NSControl.StateValue = CachedUserDefaults.intFromMacroPref(rawName, macroPreferences) == index ? .on : .off
            let buttonView = ImageTextButtonView(title: preference.localizedString, rawName: rawName, image: preference.image, state: state)
            buttons.append(buttonView)
            buttonView.onClick = { control in
                buttons.enumerated().forEach { (i, otherButtonView) in
                    if otherButtonView != buttonView {
                        otherButtonView.state = i == index ? .on : .off
                    }
                }
                controlWasChanged(buttonView.button, String(index))
                extraAction?(buttonView.button)
            }
            return buttonView
        }
        let view = NSStackView(views: buttonViews)
        view.orientation = .horizontal
        view.distribution = .fillEqually
        view.spacing = buttonSpacing
        view.alignment = .centerY
        view.translatesAutoresizingMaskIntoConstraints = false
        view.setContentHuggingPriority(.defaultLow, for: .horizontal)
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        buttonViews.forEach {
            $0.setContentHuggingPriority(.defaultLow, for: .horizontal)
            $0.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        }
        return view
    }

    static func makeLabelWithRecorder(_ labelText: String, _ rawName: String, _ shortcut: Shortcut?, _ clearable: Bool = true, labelPosition: LabelPosition = .leftWithSeparator) -> [NSView] {
        let input = CustomRecorderControl(shortcut, clearable, rawName)
        var restoreButton: NSButton?
        let views = makeLabelWithProvidedControl(labelText, rawName, input, labelPosition: labelPosition, extraAction: { _ in
            ControlsTab.shortcutChangedCallback(input)
            if let restoreButton { updateRestoreDefaultButtonVisibility(restoreButton, rawName, input) }
        })
        ControlsTab.shortcutChangedCallback(input)
        ControlsTab.shortcutControls[rawName] = (input, labelText)
        guard Preferences.defaultValues[rawName] != nil,
              let index = views.firstIndex(where: { $0 === input }) else { return views }
        let button = makeRestoreDefaultButton(rawName, input)
        restoreButton = button
        // Keeps the button in sync with programmatic objectValue changes too (e.g. accepting a
        // conflict alert clears/reassigns a recorder outside of its own recording gesture).
        input.onProgrammaticChange = { [weak button] in
            guard let button else { return }
            updateRestoreDefaultButtonVisibility(button, rawName, input)
        }
        updateRestoreDefaultButtonVisibility(button, rawName, input)
        var result = views
        result[index] = wrapRecorderWithRestoreButton(input, button)
        return result
    }

    /// A small borderless button that restores a cleared/changed shortcut to its registered default,
    /// placed right next to the recorder. Reserves its width even while hidden (alpha 0, disabled,
    /// never `isHidden`) so the recorder column never shifts as it appears and disappears.
    private static func makeRestoreDefaultButton(_ rawName: String, _ input: CustomRecorderControl) -> NSButton {
        let title = NSLocalizedString("Restore default", comment: "")
        let config = NSImage.SymbolConfiguration(pointSize: 11, weight: .medium)
        let button = NSButton(image: NSImage(systemSymbolName: "arrow.uturn.backward", accessibilityDescription: title)?
            .withSymbolConfiguration(config) ?? NSImage(), target: nil, action: nil)
        button.isBordered = false
        button.imagePosition = .imageOnly
        button.setButtonType(.momentaryChange)
        button.toolTip = title
        button.setAccessibilityLabel(title)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.widthAnchor.constraint(equalToConstant: 16).isActive = true
        button.heightAnchor.constraint(equalToConstant: 16).isActive = true
        button.onAction = { _ in restoreDefaultShortcut(rawName, input, button) }
        return button
    }

    /// Restores `rawName` to its registered default and replays the same callback path an interactive
    /// recorder edit runs (`ControlsTab.shortcuts` / registration update), instead of only clearing the
    /// preference underneath the recorder. Routes the candidate default through the same
    /// acceptability/conflict checks a live recording goes through
    /// (`CustomRecorderControlTestable.isShortcutAcceptable`, `CustomRecorderControl`'s alert methods)
    /// rather than writing it straight to preferences: a default can conflict with a shortcut the user
    /// since assigned elsewhere, and this must offer the same "unassign and continue" choice, or leave
    /// things untouched if declined or unacceptable.
    private static func restoreDefaultShortcut(_ rawName: String, _ input: CustomRecorderControl, _ button: NSButton) {
        guard let defaultShortcut = Preferences.defaultShortcut(forKey: rawName) else {
            Preferences.remove(rawName)
            input.objectValue = nil
            input.sendAction(input.action, to: input.target)
            updateRestoreDefaultButtonVisibility(button, rawName, input)
            return
        }
        switch CustomRecorderControlTestable.isShortcutAcceptable(rawName, defaultShortcut) {
        case .accepted:
            Preferences.remove(rawName)
            input.objectValue = defaultShortcut
            input.sendAction(input.action, to: input.target)
        case .modifiersOnlyButContainsKeycode:
            // The registered default is not acceptable for this control; leave it untouched rather
            // than force an invalid value onto it.
            break
        case .conflictWithExistingShortcut(let shortcutAlreadyAssigned):
            input.alertIfSameShortcutAlreadyAssigned(defaultShortcut, shortcutAlreadyAssigned)
        case .reservedByMacos(let shortcutUsingEscape):
            input.alertIfShortcutReservedByMacos(defaultShortcut, shortcutUsingEscape)
        case .usedByGameOverlay(let shortcutUsingGameOverlay):
            input.alertIfShortcutUsedByGameOverlay(defaultShortcut, shortcutUsingGameOverlay)
        }
        // Covers both a direct restore above and the no-op/declined alert paths; the conflict-clearing
        // alert paths already refresh via `onProgrammaticChange` from `updateShortcut`.
        updateRestoreDefaultButtonVisibility(button, rawName, input)
    }

    private static func updateRestoreDefaultButtonVisibility(_ button: NSButton, _ rawName: String, _ input: CustomRecorderControl) {
        let differs = ShortcutDefault.differsFromDefault(input.objectValue, Preferences.defaultShortcut(forKey: rawName))
        button.alphaValue = differs ? 1 : 0
        button.isEnabled = differs
    }

    private static func wrapRecorderWithRestoreButton(_ input: CustomRecorderControl, _ button: NSButton) -> NSView {
        let stack = NSStackView(views: [input, button])
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }

    static func makeLabelWithCheckbox(_ labelText: String, _ rawName: String, extraAction: ActionClosure? = nil, labelPosition: LabelPosition = .leftWithSeparator) -> [NSView] {
        let checkbox = NSButton(checkboxWithTitle: labelPosition == .right ? labelText : " ", target: nil, action: nil)
        checkbox.translatesAutoresizingMaskIntoConstraints = false
        checkbox.state = CachedUserDefaults.bool(rawName) ? .on : .off
        let views = makeLabelWithProvidedControl(labelText, rawName, checkbox, labelPosition: labelPosition, extraAction: extraAction)
        return views
    }

    static func makeSwitch(_ rawName: String, extraAction: ActionClosure? = nil) -> Switch {
        let button = Switch(CachedUserDefaults.bool(rawName))
        _ = setupControl(button, rawName, extraAction: extraAction)
        return button
    }

    // periphery:ignore
    static func makeCheckbox(_ rawName: String, extraAction: ActionClosure? = nil) -> NSButton {
        let checkbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
        checkbox.translatesAutoresizingMaskIntoConstraints = false
        checkbox.state = CachedUserDefaults.bool(rawName) ? .on : .off
        _ = setupControl(checkbox, rawName, extraAction: extraAction)
        return checkbox
    }

    /// A small explanatory note for a row whose control is currently disabled. Hidden by default; the
    /// caller toggles `isHidden` alongside the control's `isEnabled` state.
    static func makeDependencyNote(_ text: String) -> NSTextField {
        let note = NSTextField(wrappingLabelWithString: text)
        note.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        note.textColor = .secondaryLabelColor
        note.lineBreakMode = .byWordWrapping
        note.maximumNumberOfLines = 0
        note.isHidden = true
        return note
    }

    static func makeInfoButton(size: CGFloat = 16,
                               searchableTooltipTexts: [String] = [],
                               onClick: EventClosure? = nil,
                               onMouseEntered: EventClosure? = nil,
                               onMouseExited: EventClosure? = nil) -> ClickHoverImageView {
        let imageView = TileFontIconView(symbol: .circledInfo, size: size, color: .labelColor)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        let view = ClickHoverImageView(infoCircle: imageView)
        view.searchableStrings = Array(Set(searchableTooltipTexts.map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }.filter {
            !$0.isEmpty
        }))
        view.onClick = onClick
        view.onMouseEntered = onMouseEntered
        view.onMouseExited = onMouseExited
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: view.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            imageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
        return view
    }

    // periphery:ignore
    static func makeLabelWithCheckboxAndInfoButton(_ labelText: String,
                                                   _ rawName: String,
                                                   extraAction: ActionClosure? = nil,
                                                   labelPosition: LabelPosition = .leftWithSeparator,
                                                   onClick: EventClosure? = nil,
                                                   onMouseEntered: EventClosure? = nil,
                                                   onMouseExited: EventClosure? = nil,
                                                   size: CGFloat = 15) -> [NSView] {
        let labelCheckboxViews = makeLabelWithCheckbox(labelText, rawName, extraAction: extraAction, labelPosition: labelPosition)
        let infoButtonView = makeInfoButton(size: size, onClick: onClick, onMouseEntered: onMouseEntered, onMouseExited: onMouseExited)
        var views: [NSView] = []
        labelCheckboxViews.forEach { view in
            views.append(view)
        }
        views.append(infoButtonView)
        let hStack = NSStackView(views: views)
        hStack.orientation = .horizontal
        hStack.spacing = 8
        hStack.alignment = .centerY
        hStack.translatesAutoresizingMaskIntoConstraints = false
        return [hStack]
    }

    // periphery:ignore
    static func makeTextArea(_ nCharactersWide: CGFloat, _ nLinesHigh: Int, _ placeholder: String, _ rawName: String, extraAction: ActionClosure? = nil) -> [NSView] {
        let textArea = TextArea(nCharactersWide, nLinesHigh, placeholder)
        textArea.callback = {
            controlWasChanged(textArea, nil)
            extraAction?(textArea)
        }
        textArea.identifier = NSUserInterfaceItemIdentifier(rawName)
        textArea.stringValue = CachedUserDefaults.string(rawName)
        return [textArea]
    }

    static func dropdown_(_ rawName: String, _ macroPreferences: [MacroPreference]) -> NSPopUpButton {
        let popUp = PopupButtonLikeSystemSettings()
        popUp.addItems(withTitles: macroPreferences.map {
            $0.localizedString
        })
        popUp.selectItem(at: CachedUserDefaults.intFromMacroPref(rawName, macroPreferences))
        return popUp
    }

    static func makeDropdown(_ rawName: String, _ macroPreferences: [MacroPreference], extraAction: ActionClosure? = nil) -> NSPopUpButton {
        let dropdown = dropdown_(rawName, macroPreferences)
        return setupControl(dropdown, rawName, extraAction: extraAction) as! NSPopUpButton
    }

    /// A popup of every registry action plus a leading "None", used by the Leader and FlickRing editors.
    /// It carries each action's `stableId` as the item's represented object and reports the selected one back
    /// through `onChange` (nil for "None"), so callers persist by stableId, not by menu index.
    static func makeActionPopup(_ currentStableId: String, _ onChange: @escaping (String?) -> Void) -> NSPopUpButton {
        let popup = PopupButtonLikeSystemSettings()
        let template = actionPopupBatchTemplate ?? buildActionPopupTemplate()
        popup.menu = (template.menu.copy() as! NSMenu)
        let selectedIndex = popup.itemArray.firstIndex { ($0.representedObject as? String ?? "") == currentStableId } ?? 0
        popup.selectItem(at: selectedIndex)
        popup.onAction = { control in
            let stableId = (control as? NSPopUpButton)?.selectedItem?.representedObject as? String
            onChange((stableId?.isEmpty ?? true) ? nil : stableId)
        }
        return popup
    }

    /// The widest action title, in points; every action popup shares this so their column stays aligned
    /// regardless of which action each one has picked.
    static func actionPopupWidestItemWidth() -> CGFloat {
        return (actionPopupBatchTemplate ?? buildActionPopupTemplate()).width
    }

    private static var actionPopupBatchTemplate: (menu: NSMenu, width: CGFloat)?

    /// Opens a template shared by every action popup built while composing a single page (Leader's slots,
    /// FlickRing's directions). Unlike a process-wide cache, this cannot go stale across page rebuilds:
    /// `RegisteredAction.title()` closures can change (e.g. a launch-app/URL/profile action gets renamed),
    /// so the template is rebuilt fresh at the start of each page build and discarded at the end.
    static func beginActionPopupBatch() {
        actionPopupBatchTemplate = buildActionPopupTemplate()
    }

    static func endActionPopupBatch() {
        actionPopupBatchTemplate = nil
    }

    /// One menu (copied per popup) and one width measurement, instead of each popup re-adding N items
    /// (N calls to `action.title()`) and re-measuring them live.
    private static func buildActionPopupTemplate() -> (menu: NSMenu, width: CGFloat) {
        let font = NSFont.menuFont(ofSize: 0)
        func titleWidth(_ title: String) -> CGFloat {
            NSAttributedString(string: title, attributes: [.font: font]).size().width
        }
        let menu = NSMenu()
        let noneTitle = NSLocalizedString("None", comment: "")
        let noneItem = NSMenuItem(title: noneTitle, action: nil, keyEquivalent: "")
        noneItem.representedObject = ""
        menu.addItem(noneItem)
        var widestTitle = noneTitle
        var maxTitleWidth = titleWidth(noneTitle)
        for action in Actions.registry.registeredActions {
            let title = action.title()
            let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            item.representedObject = action.id.stableId
            menu.addItem(item)
            let width = titleWidth(title)
            if width > maxTitleWidth {
                maxTitleWidth = width
                widestTitle = title
            }
        }
        // The raw text width under-reports the popup's actual footprint (the control adds its own
        // chrome/padding around the title), which clipped the widest title. Measure the real control
        // instead: a scratch popup of the same class and control size, selected to the widest title.
        let scratchPopup = PopupButtonLikeSystemSettings()
        scratchPopup.menu = (menu.copy() as! NSMenu)
        let widestIndex = scratchPopup.itemArray.firstIndex { $0.title == widestTitle } ?? 0
        scratchPopup.selectItem(at: widestIndex)
        return (menu, scratchPopup.intrinsicContentSize.width)
    }

    // periphery:ignore
    static func makeLabelWithRadioButtons(_ labelText: String,
                                          _ rawName: String,
                                          _ values: [MacroPreference],
                                          extraAction: ActionClosure? = nil,
                                          buttonSpacing: CGFloat = 30) -> [NSView] {
        let buttons = makeRadioButtons(rawName, values, extraAction: extraAction)
        let horizontalStackView = NSStackView(views: buttons)
        horizontalStackView.translatesAutoresizingMaskIntoConstraints = false
        horizontalStackView.orientation = .horizontal
        horizontalStackView.spacing = buttonSpacing
        horizontalStackView.alignment = .centerY
        horizontalStackView.translatesAutoresizingMaskIntoConstraints = false
        return [makeLabel(labelText), horizontalStackView]
    }

    static func makeRadioButtons(_ rawName: String, _ macroPreferences: [MacroPreference], extraAction: ActionClosure? = nil) -> [NSButton] {
        var i = 0
        return macroPreferences.map {
            let button = NSButton(radioButtonWithTitle: $0.localizedString, target: nil, action: nil)
            button.translatesAutoresizingMaskIntoConstraints = false
            button.state = CachedUserDefaults.intFromMacroPref(rawName, macroPreferences) == i ? .on : .off
            _ = setupControl(button, rawName, String(i), extraAction: extraAction)
            i += 1
            return button
        }
    }

    static func makeSegmentedControl(_ rawName: String, _ macroPreferences: [MacroPreference], segmentWidth: CGFloat = -1, extraAction: ActionClosure? = nil) -> NSSegmentedControl {
        let button = NSSegmentedControl(labels: macroPreferences.map {
            $0.localizedString
        }, trackingMode: .selectOne, target: nil, action: nil)
        button.translatesAutoresizingMaskIntoConstraints = false
        applySystemSelectedSegmentStyle(button)
        for (i, preference) in macroPreferences.enumerated() {
            if segmentWidth > 0 {
                button.setWidth(segmentWidth, forSegment: i)
            }
            if #available(macOS 11.0, *) {
                if let preference = preference as? SfSymbolMacroPreference,
                   // each systemSymbolName has a different minimum macOS requirements; we need to make sure it exists
                   let symbolImage = NSImage(systemSymbolName: preference.symbolName, accessibilityDescription: nil) {
                    button.setImage(symbolImage, forSegment: i)
                }
            }
            let selectedSegment = CachedUserDefaults.intFromMacroPref(rawName, macroPreferences)
            if selectedSegment >= 0 && selectedSegment < macroPreferences.count {
                button.selectedSegment = selectedSegment
            }
            _ = setupControl(button, rawName, String(i), extraAction: extraAction)
        }
        return button
    }

    static func applySystemSelectedSegmentStyle(_ control: NSSegmentedControl) {
        if #available(macOS 10.14, *) {
            control.segmentStyle = .automatic
        } else {
            control.segmentStyle = .texturedRounded
        }
    }

    static func makeLabelWithSlider(_ labelText: String, _ rawName: String, _ minValue: Double, _ maxValue: Double,
                                    _ numberOfTickMarks: Int = 0, _ allowsTickMarkValuesOnly: Bool = false,
                                    _ unitText: String = "", width: CGFloat = 200, extraAction: ActionClosure? = nil) -> [NSView] {
        let value = CachedUserDefaults.int(rawName)
        let formatter = MeasurementFormatter()
        formatter.numberFormatter = NumberFormatter()
        let suffixText = formatter.string(from: Measurement(value: Double(value), unit: Unit(symbol: unitText)))
        let slider = NSSlider()
        slider.minValue = minValue
        slider.maxValue = maxValue
        slider.stringValue = String(value)
        slider.isContinuous = true
        if numberOfTickMarks > 0 {
            slider.numberOfTickMarks = numberOfTickMarks
        }
        slider.allowsTickMarkValuesOnly = allowsTickMarkValuesOnly
        slider.translatesAutoresizingMaskIntoConstraints = false
        slider.addOrUpdateConstraint(slider.widthAnchor, width)
        return makeLabelWithProvidedControl(labelText, rawName, slider, suffixText, extraAction: extraAction)
    }

    static func makeLabelWithProvidedControl(_ labelText: String, _ rawName: String, _ control: NSControl,
                                             _ suffixText: String? = nil, labelPosition: LabelPosition = .leftWithSeparator,
                                             extraAction: ActionClosure? = nil) -> [NSView] {
        _ = setupControl(control, rawName, extraAction: extraAction)
        if labelPosition == .right && control is NSButton {
            return [control]
        }
        let label = makeLabel(labelText)
        if labelPosition == .right {
            if let suffixText {
                return [control, label, makeSuffix(rawName, suffixText)]
            }
            return [control, label]
        }
        if let suffixText {
            return [label, control, makeSuffix(rawName, suffixText)]
        }
        return [label, control]
    }

    static func setupControl(_ control: NSControl, _ rawName: String, _ controlId: String? = nil, extraAction: ActionClosure? = nil) -> NSControl {
        control.identifier = NSUserInterfaceItemIdentifier(rawName)
        control.onAction = {
            controlWasChanged($0, controlId)
            extraAction?($0)
        }
        return control
    }

    static func controlWasChanged(_ senderControl: NSControl, _ controlId: String?) {
        if let recorderControl = senderControl as? RecorderControl {
            let key = senderControl.identifier!.rawValue
            let oldValue = Preferences.shortcut(key)
            let newValue = recorderControl.objectValue
            if oldValue == nil && newValue == nil { return }
            if let oldValue, let newValue, oldValue.isEqual(newValue) { return }
            Preferences.setShortcut(key, newValue, stringRepresentation: recorderControl.stringValue)
            return
        }
        if let newValue = LabelAndControl.getControlValue(senderControl, controlId) {
            if let oldValue = UserDefaults.standard.string(forKey: senderControl.identifier!.rawValue), newValue == oldValue {
                return
            }
            if senderControl is NSSlider {
                updateSuffixWithValue(senderControl as! NSSlider, newValue)
            }
            Preferences.set(senderControl.identifier!.rawValue, newValue)
        }
    }

    static func makeLabel(_ labelText: String, shouldFit: Bool = true) -> NSTextField {
        let label = TextField(labelText)
        label.isSelectable = false
        label.usesSingleLineMode = true
        label.alignment = .right
        if shouldFit {
            label.fit()
        }
        return label
    }

    private static func makeSuffix(_ controlName: String, _ text: String) -> NSTextField {
        let suffix = NSTextField(labelWithString: text)
        suffix.textColor = .gray
        suffix.identifier = NSUserInterfaceItemIdentifier(controlName + ControlIdentifierDiscriminator.SUFFIX.rawValue)
        return suffix
    }

    static func getControlValue(_ control: NSControl, _ controlId: String?) -> String? {
        if control is NSPopUpButton {
            return String((control as! NSPopUpButton).indexOfSelectedItem)
        } else if control is NSSlider {
            return String(format: "%.0f", control.doubleValue) // we are only interested in decimals of the provided double
        } else if control is NSButton {
            if let controlId {
                return ((control as! NSButton).state == NSButton.StateValue.on) ? controlId : nil
            } else {
                return String((control as! NSButton).state == NSButton.StateValue.on)
            }
        } else if control is Switch {
            if let controlId {
                return ((control as! Switch).state == NSButton.StateValue.on) ? controlId : nil
            } else {
                return String((control as! Switch).state == NSButton.StateValue.on)
            }
        } else if control is NSSegmentedControl {
            return String((control as! NSSegmentedControl).selectedSegment)
        } else {
            return control.stringValue
        }
    }

    private static func updateSuffixWithValue(_ control: NSControl, _ value: String) {
        let suffixIdentifierPredicate = { (view: NSView) -> Bool in
            view.identifier?.rawValue == control.identifier!.rawValue + ControlIdentifierDiscriminator.SUFFIX.rawValue
        }
        if let suffixView: NSTextField = control.superview?.subviews.first(where: suffixIdentifierPredicate) as? NSTextField {
            let regex = try! NSRegularExpression(pattern: "^[0-9]+") // first decimal
            let range = NSMakeRange(0, suffixView.stringValue.count)
            suffixView.stringValue = regex.stringByReplacingMatches(in: suffixView.stringValue, range: range, withTemplate: value)
        }
    }
}

enum ControlIdentifierDiscriminator: String {
    case SUFFIX = "_suffix"
}
