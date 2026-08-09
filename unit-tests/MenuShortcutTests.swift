import XCTest

final class MenuShortcutTests: XCTestCase {
    /// Command is encoded inverted in AXMenuItemCmdModifiers, and it is bit 8 rather than bit 1 — measured,
    /// after an assumption that put it on bit 1 would have mislabelled nearly every shortcut in the system.
    func testCommandIsPresentPreciselyWhenItsBitIsClear() {
        XCTAssertTrue(MenuShortcutFormatting.modifiers(fromMenuItemBitfield: 0).contains(.command))
        XCTAssertTrue(MenuShortcutFormatting.modifiers(fromMenuItemBitfield: 1).contains(.command))
        XCTAssertFalse(MenuShortcutFormatting.modifiers(fromMenuItemBitfield: 8).contains(.command))
        XCTAssertFalse(MenuShortcutFormatting.modifiers(fromMenuItemBitfield: 10).contains(.command))
    }

    /// Every expectation below is a real Finder menu entry measured on macOS 26.5.1, not a derivation.
    func testTheBitsMatchTheMeasuredFinderMenu() {
        // Settings… is ⌘,
        XCTAssertEqual(MenuShortcutFormatting.modifiers(fromMenuItemBitfield: 0), [.command])
        // Log Out… is ⇧⌘Q
        XCTAssertEqual(MenuShortcutFormatting.modifiers(fromMenuItemBitfield: 1), [.command, .shift])
        // Force Quit… is ⌥⌘⎋
        XCTAssertEqual(MenuShortcutFormatting.modifiers(fromMenuItemBitfield: 2), [.command, .option])
        // Log Out (alternate) is ⌥⇧⌘Q
        XCTAssertEqual(MenuShortcutFormatting.modifiers(fromMenuItemBitfield: 3), [.command, .shift, .option])
        // Lock Screen is ⌃⌘Q
        XCTAssertEqual(MenuShortcutFormatting.modifiers(fromMenuItemBitfield: 4), [.command, .control])
        // the Option-held alternates report 10: Option, and Command explicitly suppressed
        XCTAssertEqual(MenuShortcutFormatting.modifiers(fromMenuItemBitfield: 10), [.option])
        XCTAssertEqual(MenuShortcutFormatting.modifiers(fromMenuItemBitfield: 15), [.shift, .option, .control])
    }

    func testModifiersPrintInSystemOrder() {
        XCTAssertEqual(MenuShortcutFormatting.modifierSymbols([.command, .shift]), "⇧⌘")
        XCTAssertEqual(MenuShortcutFormatting.modifierSymbols([.control, .option, .shift, .command]), "⌃⌥⇧⌘")
        XCTAssertEqual(MenuShortcutFormatting.modifierSymbols([]), "")
    }

    /// An unknown glyph must produce nothing rather than a plausible wrong symbol.
    func testOnlyKnownGlyphsAreTranslated() {
        // both measured: Empty Trash reports 23, Force Quit reports 27
        XCTAssertEqual(MenuShortcutFormatting.symbol(forGlyph: 23), "⌫")
        XCTAssertEqual(MenuShortcutFormatting.symbol(forGlyph: 27), "⎋")
        XCTAssertEqual(MenuShortcutFormatting.symbol(forGlyph: 100), "←")
        XCTAssertNil(MenuShortcutFormatting.symbol(forGlyph: 4242))
    }

    func testCharactersAreUpperCasedAndSpaceBecomesVisible() {
        XCTAssertEqual(MenuShortcutFormatting.normalize(character: "w"), "W")
        XCTAssertEqual(MenuShortcutFormatting.normalize(character: " "), "␣")
        XCTAssertNil(MenuShortcutFormatting.normalize(character: ""))
        // Finder's Empty Trash… reports an invisible control character and the real key only as a glyph;
        // treating it as usable printed the modifiers with nothing after them
        XCTAssertNil(MenuShortcutFormatting.normalize(character: "\u{8}"))
        XCTAssertNil(MenuShortcutFormatting.normalize(character: "\u{1B}"))
    }

    func testTheDisplayStringReadsLikeTheSystemPrintsIt() {
        let shortcut = MenuShortcut(menuTitle: "File", itemTitle: "Save As…", modifiers: [.command, .shift], key: "S")
        XCTAssertEqual(shortcut.displayString, "⇧⌘S")
    }

    /// A bookmarks menu with thousands of entries must not stall the app, and a cut-off must be visible
    /// rather than silently shortening the list.
    func testTheScanStopsAtItsBudgetAndSaysSo() {
        XCTAssertFalse(MenuScanLimits.exceeded(totalItems: MenuScanLimits.maximumTotalItems - 1))
        XCTAssertTrue(MenuScanLimits.exceeded(totalItems: MenuScanLimits.maximumTotalItems))
        XCTAssertNil(MenuScanLimits.truncationNotice(scanned: 10, wasTruncated: false))
        XCTAssertNotNil(MenuScanLimits.truncationNotice(scanned: 800, wasTruncated: true))
    }
}
