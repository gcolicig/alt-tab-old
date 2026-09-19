import Cocoa

/// Shared row-building helpers for the settings window's "list of apps" UIs — an icon, a name and
/// subtitle, and a "⊖" remove control. Originally built for Exceptions; System Actions' Auto-Quit
/// app lists reuse the same pieces so both draw identically.
enum AppListRows {
    static let iconSize = CGFloat(22)
    static let removeWidth = CGFloat(18)
    static let addButtonSize = CGFloat(22)

    static func iconView(appUrl: URL?, isPrefix: Bool) -> NSImageView {
        let imageView = NSImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.widthAnchor.constraint(equalToConstant: iconSize).isActive = true
        imageView.heightAnchor.constraint(equalToConstant: iconSize).isActive = true
        if let appUrl {
            imageView.image = NSWorkspace.shared.icon(forFile: appUrl.path)
        } else if #available(macOS 11.0, *) {
            let symbolName = isPrefix ? "square.stack.3d.up" : "app.dashed"
            imageView.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)
        }
        return imageView
    }

    static func nameStack(_ name: String, _ subtitle: String) -> NSView {
        let title = NSTextField(labelWithString: name)
        title.font = NSFont.boldSystemFont(ofSize: NSFont.systemFontSize)
        // bundle IDs are long and their distinctive part is at both ends
        title.lineBreakMode = .byTruncatingMiddle
        title.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let subLabel = NSTextField(labelWithString: subtitle)
        subLabel.font = NSFont.systemFont(ofSize: 12)
        subLabel.textColor = .gray
        subLabel.lineBreakMode = .byTruncatingMiddle
        subLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let stack = NSStackView(views: [title, subLabel])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 2
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }

    /// Icon and name side by side in one view; as two left views the row would stack them vertically.
    static func appView(_ icon: NSView, _ names: NSView) -> NSView {
        let stack = NSStackView(views: [icon, names])
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return stack
    }

    /// The common case: icon + name straight from a bundle id, for plain app-list rows that carry no
    /// extra per-entry state (unlike Exceptions, which has its own switcher/shortcuts popups per row).
    static func appView(bundleId: String) -> NSView {
        let appUrl = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId)
        let name = appUrl.map(DefaultBrowser.displayName) ?? bundleId
        let subtitle = appUrl != nil ? bundleId : NSLocalizedString("Not installed", comment: "")
        return appView(iconView(appUrl: appUrl, isPrefix: false), nameStack(name, subtitle))
    }

    static func removeButton(onClick: @escaping () -> Void) -> NSButton {
        let button = NSButton()
        button.isBordered = false
        button.bezelStyle = .regularSquare
        if #available(macOS 11.0, *) {
            button.image = NSImage(systemSymbolName: "minus.circle", accessibilityDescription: NSLocalizedString("Remove", comment: ""))
        } else {
            button.title = "−"
        }
        button.toolTip = NSLocalizedString("Remove", comment: "")
        button.setAccessibilityLabel(NSLocalizedString("Remove", comment: ""))
        button.translatesAutoresizingMaskIntoConstraints = false
        button.widthAnchor.constraint(equalToConstant: removeWidth).isActive = true
        button.onAction = { _ in onClick() }
        return button
    }

    static func makeCircleButton(systemSymbolName: String) -> NSButton {
        let button = NSButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.isBordered = true
        button.bezelStyle = .circular
        button.showsBorderOnlyWhileMouseInside = false
        if #available(macOS 11.0, *) {
            button.image = NSImage(systemSymbolName: systemSymbolName, accessibilityDescription: nil)
        } else {
            button.image = NSImage(named: NSImage.addTemplateName)
        }
        button.imagePosition = .imageOnly
        button.imageScaling = .scaleProportionallyDown
        button.widthAnchor.constraint(equalToConstant: addButtonSize).isActive = true
        button.heightAnchor.constraint(equalToConstant: addButtonSize).isActive = true
        return button
    }
}
