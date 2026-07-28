import ShortcutRecorder

enum SearchKeyResult {
    case handled
    case passToField
    case passToShortcuts
}

class TilesViewMock {
    var isSearchEditing = false
    func handleSearchEditingKeyDown(_ event: NSEvent) -> SearchKeyResult { return .passToField }
}

class TilesPanelMock {
    var tilesView = TilesViewMock()
    var isKeyWindow = false
}

class App {
    class AppMock {
        var appIsBeingUsed = false
        var shortcutIndex = 0
        var forceDoNothingOnRelease = false
        var tilesPanel = TilesPanelMock()
    }
    static let app = AppMock()
    static var appIsBeingUsed: Bool {
        get { app.appIsBeingUsed }
        set { app.appIsBeingUsed = newValue }
    }
    static var shortcutIndex: Int {
        get { app.shortcutIndex }
        set { app.shortcutIndex = newValue }
    }
    static var forceDoNothingOnRelease: Bool {
        get { app.forceDoNothingOnRelease }
        set { app.forceDoNothingOnRelease = newValue }
    }

    static func hideUi() {
        app.appIsBeingUsed = false
        app.forceDoNothingOnRelease = false
    }
}

class TilesPanel {
    static let shared = TilesPanel()
    var isKeyWindow: Bool {
        get { App.app.tilesPanel.isKeyWindow }
        set { App.app.tilesPanel.isKeyWindow = newValue }
    }
}

class TilesView {
    static var isSearchEditing: Bool {
        get { App.app.tilesPanel.tilesView.isSearchEditing }
        set { App.app.tilesPanel.tilesView.isSearchEditing = newValue }
    }

    static func handleSearchEditingKeyDown(_ event: NSEvent) -> SearchKeyResult {
        return App.app.tilesPanel.tilesView.handleSearchEditingKeyDown(event)
    }

    static func enableSearchEditing() {
        isSearchEditing = true
        App.forceDoNothingOnRelease = true
    }
}

class ControlsTab {
    private static let globalActionShortcutPreferences = Set(
        WindowLayoutAction.allCases.map(\.shortcutPreferenceKey) + SpaceAction.all.map(\.shortcutPreferenceKey))
    static let defaultShortcuts: [String: ATShortcut] = {
        func shortcut(_ keyEquivalent: String) -> Shortcut {
            guard let shortcut = Shortcut(keyEquivalent: keyEquivalent) else { fatalError("Invalid test shortcut: \(keyEquivalent)") }
            return shortcut
        }
        func keyShortcut(_ keyCode: KeyCode) -> Shortcut {
            return Shortcut(code: keyCode, modifierFlags: [], characters: nil, charactersIgnoringModifiers: nil)
        }
        return [
            "holdShortcut": ATShortcut(shortcut("⌥"), "holdShortcut", .global, .up, 0),
            "holdShortcut2": ATShortcut(shortcut("⌥"), "holdShortcut2", .global, .up, 1),
            "holdShortcut3": ATShortcut(shortcut("⌥"), "holdShortcut3", .global, .up, 2),
            "nextWindowShortcut": ATShortcut(shortcut("⇥"), "nextWindowShortcut", .global, .down),
            "nextWindowShortcut2": ATShortcut(keyShortcut(.ansiGrave), "nextWindowShortcut2", .global, .down),
            "→": ATShortcut(shortcut("→"), "→", .local, .down),
            "←": ATShortcut(shortcut("←"), "←", .local, .down),
            "↑": ATShortcut(shortcut("↑"), "↑", .local, .down),
            "↓": ATShortcut(shortcut("↓"), "↓", .local, .down),
//        "vimCycleRight": ATShortcut(Shortcut(keyEquivalent: "l")!, "vimCycleRight", .local, .down),
//        "vimCycleLeft": ATShortcut(Shortcut(keyEquivalent: "h")!, "vimCycleLeft", .local, .down),
//        "vimCycleUp": ATShortcut(Shortcut(keyEquivalent: "k")!, "vimCycleUp", .local, .down),
//        "vimCycleDown": ATShortcut(Shortcut(keyEquivalent: "j")!, "vimCycleDown", .local, .down),
            "focusWindowShortcut": ATShortcut(keyShortcut(.space), "focusWindowShortcut", .local, .down),
            "previousWindowShortcut": ATShortcut(shortcut("⇧"), "previousWindowShortcut", .local, .down),
            "cancelShortcut": ATShortcut(shortcut("⎋"), "cancelShortcut", .local, .down),
            "searchShortcut": ATShortcut(shortcut("s"), "searchShortcut", .local, .down),
            "closeWindowShortcut": ATShortcut(shortcut("w"), "closeWindowShortcut", .local, .down),
            "minDeminWindowShortcut": ATShortcut(shortcut("m"), "minDeminWindowShortcut", .local, .down),
            "toggleFullscreenWindowShortcut": ATShortcut(shortcut("f"), "toggleFullscreenWindowShortcut", .local, .down),
            "quitAppShortcut": ATShortcut(shortcut("q"), "quitAppShortcut", .local, .down),
            "hideShowAppShortcut": ATShortcut(shortcut("h"), "hideShowAppShortcut", .local, .down),
        ]
    }()
    static var shortcuts = defaultShortcuts

    static func isGlobalActionShortcut(_ controlId: String) -> Bool {
        globalActionShortcutPreferences.contains(controlId)
    }

    static func executeAction(_ action: String) {
        shortcutsActionsTriggered.append(action)
        if action.starts(with: "holdShortcut") {
            App.app.appIsBeingUsed = false
        }
        if action.starts(with: "nextWindowShortcut") {
            App.app.appIsBeingUsed = true
            App.app.shortcutIndex = Preferences.nameToIndex(action)
        }
    }

    static var shortcutsActionsTriggered: [String] = []
}

class KeyRepeatTimer {
    static func stopTimerForRepeatingKey(_ shortcutName: String) {
    }
}

class Logger {
    static func debug(_ message: @escaping () -> Any?, file: String = #file, function: String = #function, line: Int = #line, context: Any? = nil) {}
    static func info(_ message: @escaping () -> Any?, file: String = #file, function: String = #function, line: Int = #line, context: Any? = nil) {}
    static func warning(_ message: @escaping () -> Any?, file: String = #file, function: String = #function, line: Int = #line, context: Any? = nil) {}
    static func error(_ message: @escaping () -> Any?, file: String = #file, function: String = #function, line: Int = #line, context: Any? = nil) {}
}

class Preferences {
    static var shortcutStyle: ShortcutStylePreference = .focusOnRelease
    static var holdShortcut = ["⌥", "⌥", "⌥"]
    static let minShortcutCount = 1
    static let maxShortcutCount = 9
    static let maxLaunchAppCount = 9
    static let maxOpenUrlCount = 9

    static func indexToName(_ baseName: String, _ index: Int) -> String {
        return baseName + (index == 0 ? "" : String(index + 1))
    }

    static func nameToIndex(_ name: String) -> Int {
        guard let number = name.last?.wholeNumberValue else { return 0 }
        return number - 1
    }
}

enum ShortcutStylePreference: CaseIterable {
    case focusOnRelease
    case doNothingOnRelease
    case searchOnRelease
}

enum LaunchAppAction {
    static func shortcutPreferenceKey(_ index: Int) -> String { Preferences.indexToName("launchAppShortcut", index) }
}

enum OpenUrlAction {
    static func shortcutPreferenceKey(_ index: Int) -> String { Preferences.indexToName("openUrlShortcut", index) }
}

class ModifierFlags {
    static var current: NSEvent.ModifierFlags = []
}
