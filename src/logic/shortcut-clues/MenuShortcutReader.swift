import Cocoa

/// Reads another app's menu bar over the public Accessibility API. This is the first module that reads
/// somebody else's shortcuts instead of running our own, so it registers no actions and touches no private
/// API.
///
/// Every call here is synchronous AX IPC. It must run on the AX queue, never in an event callback, and
/// never against our own process.
enum MenuShortcutReader {
    private static let cmdCharAttribute = "AXMenuItemCmdChar"
    private static let cmdVirtualKeyAttribute = "AXMenuItemCmdVirtualKey"
    private static let cmdGlyphAttribute = "AXMenuItemCmdGlyph"
    private static let cmdModifiersAttribute = "AXMenuItemCmdModifiers"

    struct Result {
        let shortcuts: [MenuShortcut]
        let wasTruncated: Bool
        let scannedItems: Int
    }

    static func read(pid: pid_t) -> Result? {
        guard pid != ProcessInfo.processInfo.processIdentifier else { return nil }
        let application = AXUIElementCreateApplication(pid)
        guard let menuBar = element(application, kAXMenuBarAttribute) else { return nil }
        var shortcuts = [MenuShortcut]()
        var scanned = 0
        var truncated = false
        children(menuBar).forEach { topLevel in
            let title = string(topLevel, kAXTitleAttribute) ?? ""
            // the top level item holds one submenu, which is the actual menu
            children(topLevel).forEach { menu in
                collect(menu, menuTitle: title, depth: 0, into: &shortcuts, scanned: &scanned, truncated: &truncated)
            }
        }
        return Result(shortcuts: shortcuts, wasTruncated: truncated, scannedItems: scanned)
    }

    private static func collect(_ menu: AXUIElement, menuTitle: String, depth: Int,
                                into shortcuts: inout [MenuShortcut], scanned: inout Int, truncated: inout Bool) {
        guard depth < MenuScanLimits.maximumDepth else {
            truncated = true
            return
        }
        let items = children(menu)
        if items.count > MenuScanLimits.maximumItemsPerMenu { truncated = true }
        for item in items.prefix(MenuScanLimits.maximumItemsPerMenu) {
            guard !MenuScanLimits.exceeded(totalItems: scanned) else {
                truncated = true
                return
            }
            scanned += 1
            if let shortcut = shortcut(item, menuTitle: menuTitle) {
                shortcuts.append(shortcut)
            }
            children(item).forEach {
                collect($0, menuTitle: menuTitle, depth: depth + 1, into: &shortcuts, scanned: &scanned, truncated: &truncated)
            }
        }
    }

    private static func shortcut(_ item: AXUIElement, menuTitle: String) -> MenuShortcut? {
        guard let title = string(item, kAXTitleAttribute), !title.isEmpty else { return nil }
        guard let raw = integer(item, cmdModifiersAttribute) else { return nil }
        // char is preferred over glyph: the measurement showed it already carries symbols like ⎋ directly,
        // while the glyph numbering is only partly verified. It is blank for some items, hence the fallback.
        let character = string(item, cmdCharAttribute).flatMap { MenuShortcutFormatting.normalize(character: $0) }
        let glyphSymbol = integer(item, cmdGlyphAttribute).flatMap { MenuShortcutFormatting.symbol(forGlyph: $0) }
        let key = character ?? glyphSymbol
        guard let key else { return nil }
        return MenuShortcut(menuTitle: menuTitle, itemTitle: title,
                            modifiers: MenuShortcutFormatting.modifiers(fromMenuItemBitfield: raw), key: key)
    }

    /// Diagnostic dump used to verify the encodings the spec flagged as unverified, before the display was
    /// built on them. Kept because the same questions return with every macOS major.
    static func dumpRawAttributes(pid: pid_t, limit: Int = 25) {
        let application = AXUIElementCreateApplication(pid)
        guard let menuBar = element(application, kAXMenuBarAttribute) else {
            Logger.info { "shortcut clues: no menu bar for pid \(pid)" }
            return
        }
        var printed = 0
        children(menuBar).forEach { topLevel in
            let menuTitle = string(topLevel, kAXTitleAttribute) ?? ""
            children(topLevel).forEach { menu in
                children(menu).forEach { item in
                    guard printed < limit, let title = string(item, kAXTitleAttribute), !title.isEmpty else { return }
                    let modifiers = integer(item, cmdModifiersAttribute).map(String.init) ?? "nil"
                    let glyph = integer(item, cmdGlyphAttribute).map(String.init) ?? "nil"
                    let virtualKey = integer(item, cmdVirtualKeyAttribute).map(String.init) ?? "nil"
                    let character = string(item, cmdCharAttribute) ?? "nil"
                    guard modifiers != "nil" || character != "nil" else { return }
                    printed += 1
                    Logger.info { "shortcut clues raw: menu:\(menuTitle) item:\(title) char:\(character) glyph:\(glyph) virtualKey:\(virtualKey) modifiers:\(modifiers)" }
                }
            }
        }
    }

    private static func children(_ element: AXUIElement) -> [AXUIElement] {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &value) == .success else { return [] }
        return value as? [AXUIElement] ?? []
    }

    private static func element(_ element: AXUIElement, _ attribute: String) -> AXUIElement? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
        guard let value, CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return (value as! AXUIElement)
    }

    private static func string(_ element: AXUIElement, _ attribute: String) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
        return value as? String
    }

    private static func integer(_ element: AXUIElement, _ attribute: String) -> Int? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
        return (value as? NSNumber)?.intValue
    }
}
