import Cocoa

final class SettingsSidebarCellView: NSTableCellView {
    static let identifier = NSUserInterfaceItemIdentifier(rawValue: "SettingsSidebarCell")
    private let iconView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")

    override var backgroundStyle: NSView.BackgroundStyle {
        didSet { refreshStyle() }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
    }

    required init?(coder: NSCoder) {
        fatalError("Class only supports programmatic initialization")
    }

    private func setupView() {
        iconView.imageScaling = .scaleProportionallyDown
        iconView.setContentHuggingPriority(.required, for: .horizontal)
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        iconView.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(iconView)
        addSubview(titleLabel)
        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 16),
            iconView.heightAnchor.constraint(equalToConstant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 9),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -10),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
        refreshStyle()
    }

    func configure(_ section: SettingsSection) {
        titleLabel.stringValue = section.title
        iconView.image = section.icon
        iconView.image?.isTemplate = true
        refreshStyle()
    }

    private func refreshStyle() {
        let selected = backgroundStyle == .emphasized
        titleLabel.font = NSFont.systemFont(ofSize: 13.5, weight: .medium)
        titleLabel.textColor = selected ? .white : .labelColor
        if #available(macOS 10.14, *) {
            iconView.contentTintColor = selected ? .white : .secondaryLabelColor
        }
    }
}

extension SettingsWindow: NSTableViewDataSource, NSTableViewDelegate {
    private static let headerRowHeight = CGFloat(26)

    func numberOfRows(in tableView: NSTableView) -> Int {
        sidebarRows.count
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        sidebarRows[row].sectionId == nil ? Self.headerRowHeight : 30
    }

    func tableView(_ tableView: NSTableView, isGroupRow row: Int) -> Bool {
        sidebarRows[row].sectionId == nil
    }

    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        sidebarRows[row].sectionId != nil
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let id = sidebarRows[row].sectionId, let section = sections.first(where: { $0.id == id }) else {
            guard case .header(let group) = sidebarRows[row] else { return nil }
            return SettingsSidebarHeaderView(Self.groupTitle(group))
        }
        let cell = tableView.makeView(withIdentifier: SettingsSidebarCellView.identifier, owner: self) as? SettingsSidebarCellView ?? {
            let view = SettingsSidebarCellView()
            view.identifier = SettingsSidebarCellView.identifier
            return view
        }()
        cell.configure(section)
        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        let row = sidebarTableView.selectedRow
        guard row >= 0, row < sidebarRows.count, let id = sidebarRows[row].sectionId,
              let section = sections.first(where: { $0.id == id }) else { return }
        chosenSectionId = section.id
        if selectedSectionId == section.id { return }
        selectSection(section, scroll: true, selectInSidebar: false)
    }

    private static func groupTitle(_ group: SettingsSidebarGroup) -> String {
        switch group {
            case .app: return App.name
            case .switcher: return NSLocalizedString("Switcher", comment: "")
            case .windows: return NSLocalizedString("Windows", comment: "")
            case .triggers: return NSLocalizedString("Triggers", comment: "")
            case .devices: return NSLocalizedString("Devices", comment: "")
            case .actions: return NSLocalizedString("Actions", comment: "")
        }
    }
}

private final class SettingsSidebarHeaderView: NSTableCellView {
    convenience init(_ title: String) {
        self.init(frame: .zero)
        let label = NSTextField(labelWithString: title)
        label.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        label.textColor = .tertiaryLabelColor
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -3),
        ])
    }
}
