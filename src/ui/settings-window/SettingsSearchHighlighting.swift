import Cocoa

extension SettingsWindow {
    func collectSearchContent(_ sectionTitle: NSTextField, _ sectionDescription: NSTextField, _ root: NSView) -> ([String], [SettingsSearchHighlightTarget]) {
        var textValues = [String]()
        var highlightTargets = [SettingsSearchHighlightTarget]()
        textValues.append(sectionTitle.stringValue)
        textValues.append(sectionDescription.stringValue)
        if let target = highlightTarget(sectionTitle) {
            highlightTargets.append(target)
        }
        if let target = highlightTarget(sectionDescription) {
            highlightTargets.append(target)
        }
        collectSearchContent(root, &textValues, &highlightTargets)
        return (Array(Set(textValues)), highlightTargets)
    }

    func collectSearchContent(_ root: NSView,
                                      _ textValues: inout [String],
                                      _ highlightTargets: inout [SettingsSearchHighlightTarget]) {
        if let textField = root as? NSTextField {
            let value = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !value.isEmpty {
                textValues.append(value)
                if let target = highlightTarget(textField) {
                    highlightTargets.append(target)
                }
            }
        } else if let popUpButton = root as? NSPopUpButton {
            let value = popUpButton.title.trimmingCharacters(in: .whitespacesAndNewlines)
            if !value.isEmpty {
                textValues.append(value)
            }
            popUpButton.itemTitles.forEach {
                let value = $0.trimmingCharacters(in: .whitespacesAndNewlines)
                if !value.isEmpty {
                    textValues.append(value)
                }
            }
            if let target = highlightTarget(popUpButton) {
                highlightTargets.append(target)
            }
        } else if let tableView = root as? TableView {
            SettingsWindow.searchStrings(tableView).forEach {
                textValues.append($0)
            }
            if let target = highlightTarget(tableView) {
                highlightTargets.append(target)
            }
        } else if let button = root as? NSButton {
            let value = button.title.trimmingCharacters(in: .whitespacesAndNewlines)
            if !value.isEmpty {
                textValues.append(value)
            }
            if let target = highlightTarget(button) {
                highlightTargets.append(target)
            }
        } else if let segmentedControl = root as? NSSegmentedControl {
            (0..<segmentedControl.segmentCount).forEach {
                let value = (segmentedControl.label(forSegment: $0) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                if !value.isEmpty {
                    textValues.append(value)
                }
            }
            if let target = highlightTarget(segmentedControl) {
                highlightTargets.append(target)
            }
        } else if let infoButton = root as? ClickHoverImageView {
            SettingsWindow.searchStrings(infoButton).forEach {
                textValues.append($0)
            }
            if let target = highlightTarget(infoButton) {
                highlightTargets.append(target)
            }
        } else if let textView = root as? NSTextView {
            let value = textView.string.trimmingCharacters(in: .whitespacesAndNewlines)
            if !value.isEmpty {
                textValues.append(value)
            }
        }
        root.subviews.forEach { collectSearchContent($0, &textValues, &highlightTargets) }
    }

    func highlightTarget(_ textField: NSTextField) -> SettingsSearchHighlightTarget? {
        guard !textField.stringValue.isEmpty else { return nil }
        var baseAttributedString: NSAttributedString?
        var highlightedText = ""
        var isHighlighted = false
        return SettingsSearchHighlightTarget({ query in
            SettingsSearch.match(query, in: textField.stringValue)?.ranges ?? []
        }, { ranges in
            let text = textField.stringValue
            if !isHighlighted || highlightedText != text {
                baseAttributedString = textField.attributedStringValue
                highlightedText = text
            }
            let mutable = NSMutableAttributedString(attributedString: baseAttributedString ?? textField.attributedStringValue)
            let nsRanges = ranges.compactMap { SettingsWindow.characterRangeToNSRange($0, in: text) }
            nsRanges.forEach {
                mutable.addAttribute(.foregroundColor, value: Appearance.searchMatchForegroundColor, range: $0)
            }
            textField.attributedStringValue = mutable
            SettingsWindow.applyRoundedHighlights(to: textField, attributedString: mutable, ranges: nsRanges)
            isHighlighted = true
        }, {
            guard isHighlighted else { return }
            if let baseAttributedString {
                textField.attributedStringValue = baseAttributedString
            }
            SettingsWindow.clearRoundedHighlights(from: textField)
            baseAttributedString = nil
            highlightedText = ""
            isHighlighted = false
        })
    }

    func highlightTarget(_ popUpButton: NSPopUpButton) -> SettingsSearchHighlightTarget? {
        controlHighlightTarget(popUpButton) {
            SettingsWindow.searchStrings(popUpButton)
        }
    }

    private func highlightTarget(_ tableView: TableView) -> SettingsSearchHighlightTarget? {
        let targetView = tableView.enclosingScrollView ?? tableView
        return controlHighlightTarget(targetView) {
            SettingsWindow.searchStrings(tableView)
        }
    }

    private func highlightTarget(_ button: NSButton) -> SettingsSearchHighlightTarget? {
        guard SettingsWindow.sheet(forSearchButton: button) != nil else { return nil }
        return controlHighlightTarget(button) {
            var values = [String]()
            SettingsWindow.appendTrimmed(button.title, &values)
            if let sheet = SettingsWindow.sheet(forSearchButton: button) {
                values.append(contentsOf: SettingsWindow.sheetSearchStrings(sheet))
            }
            return Array(Set(values))
        }
    }

    func highlightTarget(_ segmentedControl: NSSegmentedControl) -> SettingsSearchHighlightTarget? {
        let segmentLabels = (0..<segmentedControl.segmentCount).map {
            SettingsWindow.trimmedText(segmentedControl.label(forSegment: $0) ?? "")
        }
        if segmentLabels.allSatisfy(\.isEmpty) { return nil }
        var matchingSegmentIndexes = [Int]()
        return SettingsSearchHighlightTarget({ query in
            matchingSegmentIndexes = []
            segmentLabels.enumerated().forEach { index, label in
                guard !label.isEmpty else { return }
                if SettingsSearch.match(query, in: label) != nil {
                    matchingSegmentIndexes.append(index)
                }
            }
            if matchingSegmentIndexes.isEmpty { return [] }
            return [0..<1]
        }, { _ in
            SettingsWindow.applySegmentedControlHighlight(to: segmentedControl, segmentIndexes: matchingSegmentIndexes)
        }, {
            SettingsWindow.clearSegmentedControlHighlight(from: segmentedControl)
        })
    }

    func highlightTarget(_ infoButton: ClickHoverImageView) -> SettingsSearchHighlightTarget? {
        controlHighlightTarget(infoButton) {
            SettingsWindow.searchStrings(infoButton)
        }
    }

    private func controlHighlightTarget(_ control: NSView, _ searchableStrings: @escaping () -> [String]) -> SettingsSearchHighlightTarget? {
        if searchableStrings().isEmpty { return nil }
        return SettingsSearchHighlightTarget({ query in
            searchableStrings().contains {
                SettingsSearch.match(query, in: $0) != nil
            }
        }, {
            SettingsWindow.applyControlHighlight(to: control)
        }, {
            SettingsWindow.clearControlHighlight(from: control)
        })
    }

    private static func characterRangeToNSRange(_ range: Range<Int>, in text: String) -> NSRange? {
        if range.lowerBound < 0 || range.upperBound > text.count || range.isEmpty { return nil }
        let start = text.index(text.startIndex, offsetBy: range.lowerBound)
        let end = text.index(text.startIndex, offsetBy: range.upperBound)
        return NSRange(start..<end, in: text)
    }

    private static func clearRoundedHighlights(from view: NSView) {
        view.layer?.sublayers?.filter { $0.name == roundedHighlightLayerName }.forEach { $0.removeFromSuperlayer() }
    }

    private static func clearControlHighlight(from view: NSView) {
        view.layer?.sublayers?.filter { $0.name == controlHighlightLayerName }.forEach { $0.removeFromSuperlayer() }
    }

    private static func clearSegmentedControlHighlight(from view: NSView) {
        view.layer?.sublayers?.filter { $0.name == segmentedControlHighlightLayerName }.forEach { $0.removeFromSuperlayer() }
    }

    private static func applySegmentedControlHighlight(to control: NSSegmentedControl, segmentIndexes: [Int]) {
        clearSegmentedControlHighlight(from: control)
        control.layoutSubtreeIfNeeded()
        guard !segmentIndexes.isEmpty else { return }
        control.wantsLayer = true
        let segmentRects = segmentedControlSegmentRects(control)
        segmentIndexes.forEach {
            guard segmentRects.indices.contains($0) else { return }
            let rect = segmentRects[$0].insetBy(dx: 1, dy: 1)
            guard rect.width > 0, rect.height > 0 else { return }
            let layer = noAnimation { CAShapeLayer() }
            layer.name = segmentedControlHighlightLayerName
            layer.fillColor = Appearance.searchMatchHighlightColor.cgColor
            let cornerRadius = min(max(rect.height * 0.3, 4), 7)
            layer.path = CGPath(roundedRect: rect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
            control.layer?.insertSublayer(layer, at: 0)
        }
    }

    private static func segmentedControlSegmentRects(_ control: NSSegmentedControl) -> [CGRect] {
        let segmentCount = control.segmentCount
        if segmentCount <= 0 { return [] }
        let widths = (0..<segmentCount).map { max(control.width(forSegment: $0), 0) }
        let explicitWidthTotal = widths.reduce(0) {
            $0 + ($1 > 0 ? $1 : 0)
        }
        let autoSegmentCount = widths.filter { $0 == 0 }.count
        let autoSegmentWidth = autoSegmentCount > 0 ? max(control.bounds.width - explicitWidthTotal, 0) / CGFloat(autoSegmentCount) : 0
        var currentX = control.bounds.minX
        return widths.enumerated().map { index, width in
            let resolvedWidth = width > 0 ? width : autoSegmentWidth
            let isLastSegment = index == segmentCount - 1
            let segmentWidth = isLastSegment ? max(control.bounds.maxX - currentX, 0) : resolvedWidth
            defer { currentX += segmentWidth }
            return CGRect(x: currentX, y: control.bounds.minY, width: segmentWidth, height: control.bounds.height)
        }
    }

    private static func applyControlHighlight(to view: NSView) {
        clearControlHighlight(from: view)
        view.layoutSubtreeIfNeeded()
        guard view.bounds.width > 0, view.bounds.height > 0 else { return }
        view.wantsLayer = true
        let layer = noAnimation { CAShapeLayer() }
        layer.name = controlHighlightLayerName
        layer.fillColor = Appearance.searchMatchHighlightColor.cgColor
        let rect = view.bounds.insetBy(dx: -controlHighlightInset, dy: -controlHighlightInset)
        let cornerRadius = min(max(rect.height * 0.35, controlHighlightMinCornerRadius), controlHighlightMaxCornerRadius)
        layer.path = CGPath(roundedRect: rect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
        view.layer?.insertSublayer(layer, at: 0)
    }

    private static func applyRoundedHighlights(to textField: NSTextField,
                                               attributedString: NSAttributedString,
                                               ranges: [NSRange]) {
        clearRoundedHighlights(from: textField)
        guard !ranges.isEmpty else { return }
        textField.layoutSubtreeIfNeeded()
        let textRect = textDrawingRect(textField)
        guard textRect.width > 0, textRect.height > 0 else { return }
        textField.wantsLayer = true
        let textStorage = NSTextStorage(attributedString: attributedString)
        let layoutManager = NSLayoutManager()
        let textContainer = NSTextContainer(size: NSSize(width: textRect.width, height: CGFloat.greatestFiniteMagnitude))
        textContainer.lineFragmentPadding = 0
        textContainer.maximumNumberOfLines = textField.maximumNumberOfLines
        textContainer.lineBreakMode = textField.lineBreakMode
        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)
        layoutManager.ensureLayout(for: textContainer)
        let usedRect = layoutManager.usedRect(for: textContainer)
        let horizontalOffset = textRect.minX
        let verticalOffset = textRect.minY + max(0, (textRect.height - usedRect.height) / 2)
        ranges.forEach { range in
            let glyphRange = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
            guard glyphRange.length > 0 else { return }
            layoutManager.enumerateEnclosingRects(forGlyphRange: glyphRange, withinSelectedGlyphRange: NSRange(location: NSNotFound, length: 0), in: textContainer) { rect, _ in
                var highlightRect = rect.offsetBy(dx: horizontalOffset, dy: verticalOffset)
                highlightRect = highlightRect.insetBy(dx: -roundedHighlightHorizontalInset, dy: -roundedHighlightVerticalInset)
                highlightRect = leadingTrimmedHighlightRect(highlightRect, textField)
                let layer = noAnimation { CAShapeLayer() }
                layer.name = roundedHighlightLayerName
                layer.fillColor = Appearance.searchMatchHighlightColor.cgColor
                layer.path = CGPath(roundedRect: highlightRect, cornerWidth: roundedHighlightCornerRadius, cornerHeight: roundedHighlightCornerRadius, transform: nil)
                textField.layer?.insertSublayer(layer, at: 0)
            }
        }
    }

    private static func leadingTrimmedHighlightRect(_ rect: CGRect, _ textField: NSTextField) -> CGRect {
        let trimmedWidth = max(rect.width - roundedHighlightLeadingTrim, 0.5)
        if textField.userInterfaceLayoutDirection == .rightToLeft {
            return CGRect(x: rect.minX, y: rect.minY, width: trimmedWidth, height: rect.height)
        }
        return CGRect(x: rect.minX + roundedHighlightLeadingTrim, y: rect.minY, width: trimmedWidth, height: rect.height)
    }

    private static func textDrawingRect(_ textField: NSTextField) -> CGRect {
        textField.cell?.drawingRect(forBounds: textField.bounds) ?? textField.bounds
    }

    static func appendTrimmed(_ text: String, _ values: inout [String]) {
        let value = trimmedText(text)
        if !value.isEmpty {
            values.append(value)
        }
    }

    private static func trimmedText(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func searchStrings(_ popUpButton: NSPopUpButton) -> [String] {
        var values = [String]()
        appendTrimmed(popUpButton.title, &values)
        popUpButton.itemTitles.forEach {
            appendTrimmed($0, &values)
        }
        return Array(Set(values))
    }

    private static func searchStrings(_ segmentedControl: NSSegmentedControl) -> [String] {
        var values = [String]()
        (0..<segmentedControl.segmentCount).forEach {
            appendTrimmed(segmentedControl.label(forSegment: $0) ?? "", &values)
        }
        return Array(Set(values))
    }

    static func searchStrings(_ infoButton: ClickHoverImageView) -> [String] {
        var values = [String]()
        infoButton.searchableStrings.forEach {
            appendTrimmed($0, &values)
        }
        return Array(Set(values))
    }

    static func searchStrings(_ tableView: TableView) -> [String] {
        var values = [String]()
        tableView.tableColumns.forEach {
            appendTrimmed($0.headerCell.stringValue, &values)
            appendTrimmed($0.headerToolTip ?? "", &values)
        }
        tableView.items.forEach {
            appendTrimmed($0.bundleIdentifier, &values)
            appendTrimmed($0.hide.localizedString, &values)
            appendTrimmed($0.ignore.localizedString, &values)
        }
        return Array(Set(values))
    }
}
