import Cocoa

/// A collapsible section used in the Settings window in place of a modal sheet.
/// Header row (chevron + bold title + optional trailing summary) toggles a content view below it.
class DisclosureSection: NSStackView {
    private static let chevronPointSize = CGFloat(11)
    private static let headerSpacing = CGFloat(6)

    /// Expanded/collapsed state persisted only for the lifetime of the process (no Preferences),
    /// keyed by an id supplied by the caller so re-opening Settings keeps the section's last state.
    private static var expandedStateById = [String: Bool]()

    private let id: String
    private let chevronButton = NSButton()
    private let titleLabel = NSTextField(labelWithString: "")
    private let summaryLabel = NSTextField(labelWithString: "")
    private let headerButton = NSButton()
    private let headerRow = NSStackView()
    private var content: NSView
    private let summary: (() -> String)?

    var title: String {
        get { titleLabel.stringValue }
        set { titleLabel.stringValue = newValue }
    }

    var isExpanded: Bool {
        get { DisclosureSection.expandedStateById[id] ?? false }
        set {
            DisclosureSection.expandedStateById[id] = newValue
            refreshExpandedState()
        }
    }

    init(id: String, title: String, content: NSView, summary: (() -> String)? = nil) {
        self.id = id
        self.content = content
        self.summary = summary
        super.init(frame: .zero)
        orientation = .vertical
        alignment = .leading
        spacing = DisclosureSection.headerSpacing
        setupChevron()
        setupTitleLabel(title)
        setupSummaryLabel()
        setupHeaderRow()
        setupHeaderButton()
        addArrangedSubview(headerRow)
        addArrangedSubview(content)
        refreshExpandedState()
    }

    required init?(coder: NSCoder) {
        fatalError("Class only supports programmatic initialization")
    }

    /// Replaces the content view in place (used when the underlying preferences change the layout,
    /// e.g. CustomizeStyleSection rebuilding after the appearance style changes).
    func setContent(_ newContent: NSView) {
        removeArrangedSubview(content)
        content.removeFromSuperview()
        content = newContent
        addArrangedSubview(content)
        refreshExpandedState()
    }

    func expand() {
        guard !isExpanded else { return }
        isExpanded = true
    }

    private func setupChevron() {
        let config = NSImage.SymbolConfiguration(pointSize: DisclosureSection.chevronPointSize, weight: .semibold)
        chevronButton.image = NSImage(systemSymbolName: "chevron.right", accessibilityDescription: nil)?
            .withSymbolConfiguration(config)
        chevronButton.isBordered = false
        chevronButton.imagePosition = .imageOnly
        chevronButton.setButtonType(.momentaryChange)
        chevronButton.target = self
        chevronButton.action = #selector(toggle)
        chevronButton.translatesAutoresizingMaskIntoConstraints = false
        chevronButton.widthAnchor.constraint(equalToConstant: 16).isActive = true
        chevronButton.heightAnchor.constraint(equalToConstant: 16).isActive = true
    }

    private func setupTitleLabel(_ title: String) {
        titleLabel.stringValue = title
        titleLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        titleLabel.lineBreakMode = .byTruncatingTail
    }

    private func setupSummaryLabel() {
        summaryLabel.font = NSFont.systemFont(ofSize: 12)
        summaryLabel.textColor = NSColor.secondaryLabelColor
        summaryLabel.alignment = .right
    }

    private func setupHeaderRow() {
        headerRow.orientation = .horizontal
        headerRow.alignment = .centerY
        headerRow.spacing = DisclosureSection.headerSpacing
        headerRow.addArrangedSubview(chevronButton)
        headerRow.addArrangedSubview(titleLabel)
        if summary != nil {
            let spacer = NSView()
            spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
            headerRow.addArrangedSubview(spacer)
            headerRow.addArrangedSubview(summaryLabel)
        }
        headerRow.translatesAutoresizingMaskIntoConstraints = false
    }

    private func setupHeaderButton() {
        // Transparent full-width button layered under the header row so clicking anywhere in the
        // header (not just the chevron) toggles the section.
        headerButton.isBordered = false
        headerButton.title = ""
        headerButton.target = self
        headerButton.action = #selector(toggle)
        headerButton.translatesAutoresizingMaskIntoConstraints = false
        headerRow.addSubview(headerButton, positioned: .below, relativeTo: nil)
        headerButton.leadingAnchor.constraint(equalTo: headerRow.leadingAnchor).isActive = true
        headerButton.trailingAnchor.constraint(equalTo: headerRow.trailingAnchor).isActive = true
        headerButton.topAnchor.constraint(equalTo: headerRow.topAnchor).isActive = true
        headerButton.bottomAnchor.constraint(equalTo: headerRow.bottomAnchor).isActive = true
    }

    @objc private func toggle() {
        isExpanded.toggle()
    }

    private func refreshExpandedState() {
        let expanded = isExpanded
        let config = NSImage.SymbolConfiguration(pointSize: DisclosureSection.chevronPointSize, weight: .semibold)
        chevronButton.image = NSImage(systemSymbolName: expanded ? "chevron.down" : "chevron.right", accessibilityDescription: nil)?
            .withSymbolConfiguration(config)
        content.isHidden = !expanded
        if let summary {
            summaryLabel.stringValue = expanded ? "" : summary()
        }
    }
}
