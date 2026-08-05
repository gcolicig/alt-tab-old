import AppKit
import Foundation

/// One menu command with a keyboard shortcut, as read from another app's menu bar.
struct MenuShortcut: Equatable {
    let menuTitle: String
    let itemTitle: String
    let modifiers: NSEvent.ModifierFlags
    /// The printable character, already upper-cased, or a symbol for a special key.
    let key: String

    var displayString: String {
        MenuShortcutFormatting.modifierSymbols(modifiers) + key
    }
}

enum MenuShortcutFormatting {
    /// `AXMenuItemCmdModifiers` is a bitfield in which Command is encoded inverted: a set bit means the
    /// shortcut does *not* use Command. Measured against Finder's real menus on macOS 26.5.1 rather than
    /// assumed, because getting this backwards mislabels nearly every shortcut in the system. The values
    /// that pinned it down: `Settings…` = 0 for ⌘, `Log Out…` = 1 for ⇧⌘, `Force Quit…` = 2 for ⌥⌘,
    /// `Lock Screen` = 4 for ⌃⌘, and the Option-held alternates = 10 for a plain ⌥ with no Command.
    static let shiftBit = 1
    static let optionBit = 2
    static let controlBit = 4
    static let commandSuppressedBit = 8

    static func modifiers(fromMenuItemBitfield raw: Int) -> NSEvent.ModifierFlags {
        var flags = NSEvent.ModifierFlags()
        if raw & commandSuppressedBit == 0 { flags.insert(.command) }
        if raw & shiftBit != 0 { flags.insert(.shift) }
        if raw & optionBit != 0 { flags.insert(.option) }
        if raw & controlBit != 0 { flags.insert(.control) }
        return flags
    }

    /// System order, matching how macOS itself prints a shortcut.
    static func modifierSymbols(_ modifiers: NSEvent.ModifierFlags) -> String {
        var symbols = ""
        if modifiers.contains(.control) { symbols += "⌃" }
        if modifiers.contains(.option) { symbols += "⌥" }
        if modifiers.contains(.shift) { symbols += "⇧" }
        if modifiers.contains(.command) { symbols += "⌘" }
        return symbols
    }

    /// `AXMenuItemCmdGlyph` carries the Carbon menu glyph numbers for keys without a printable character.
    /// Measured on macOS 26.5.1: 23 for `⌫` (Empty Trash) and 27 for `⎋` (Force Quit). The remaining
    /// entries are the documented Carbon constants and are *not* individually verified, which is why an
    /// unknown glyph yields nothing instead of a plausible guess: a missing symbol is honest, a wrong one
    /// teaches the user a shortcut that does not exist.
    static func symbol(forGlyph glyph: Int) -> String? {
        switch glyph {
            case 2: return "⇥"
            case 10: return "⌦"
            case 11: return "↩"
            case 23: return "⌫"
            case 27: return "⎋"
            case 100: return "←"
            case 101: return "→"
            case 104: return "↑"
            case 106: return "↓"
            case 98: return "⇞"
            case 99: return "⇟"
            case 115: return "↖"
            case 119: return "↘"
            default: return nil
        }
    }

    /// Menus report a bare character; the display convention is upper case, and a space needs a symbol
    /// because an invisible shortcut is unreadable.
    ///
    /// Items whose key is a special one report a control character here rather than nothing — Finder's
    /// `Empty Trash…` carries an invisible character and the real symbol only in the glyph. Treating those
    /// as absent is what lets the glyph fallback run; returning them printed `⇧⌘` with nothing after it.
    static func normalize(character: String) -> String? {
        guard !character.isEmpty else { return nil }
        if character == " " { return "␣" }
        let unusable = character.unicodeScalars.allSatisfy {
            CharacterSet.controlCharacters.contains($0) || CharacterSet.whitespacesAndNewlines.contains($0)
        }
        return unusable ? nil : character.uppercased()
    }
}

/// Hard limits so a bookmarks menu with thousands of entries cannot stall the app. The reference
/// implementation is documented as having exactly that problem in browsers.
enum MenuScanLimits {
    static let maximumDepth = 6
    static let maximumItemsPerMenu = 200
    static let maximumTotalItems = 800

    static func exceeded(totalItems: Int) -> Bool {
        totalItems >= maximumTotalItems
    }

    static func truncationNotice(scanned: Int, wasTruncated: Bool) -> String? {
        guard wasTruncated else { return nil }
        return String(format: NSLocalizedString("Only the first %d menu entries were read.", comment: ""), scanned)
    }
}
