import Foundation

/// Every built-in action added from the Supercharge comparison (stories 10, 12, 14). The raw value is the
/// persisted `stableId`, so Leader and FlickRing bindings survive renames of the Swift case.
enum SystemAction: String, CaseIterable {
    case isolateWindow = "windowFocus.isolate"
    case minimizeAppOthers = "windowFocus.minimizeAppOthers"
    case hideOtherApps = "windowFocus.hideOthers"
    case hideAll = "windowFocus.hideAll"
    case focusThreeWindows = "windowFocus.focusThree"
    case quitAllApps = "apps.quitAll"
    case quitAllAppsExceptFrontmost = "apps.quitAllExceptFrontmost"
    case autoQuitToggle = "apps.autoQuit.toggle"
    case pickColor = "tools.pickColor"
    case captureText = "tools.captureText"
    case captureTranslate = "tools.captureTranslate"
    case scanQr = "tools.scanQr"
    case scanQrClipboard = "tools.scanQrClipboard"
    case clearVisibleNotifications = "notifications.clearVisible"
    case clearAllNotifications = "notifications.clearAll"
    case clearClipboard = "system.clearClipboard"
    case ejectAllDisks = "system.ejectAllDisks"
    case sleepDisplays = "system.sleepDisplays"
    case catModeToggle = "system.catMode.toggle"
    case muteOutputToggle = "audio.muteOutput.toggle"
    case muteInputToggle = "audio.muteInput.toggle"
    case functionKeysToggle = "keyboard.fnKeys.toggle"
    case keepAwakeToggle = "keepAwake.toggle"
    case keepAwakeStop = "keepAwake.stop"
    case keepAwakeIndefinitely = "keepAwake.start.indefinitely"
    case keepAwake15Minutes = "keepAwake.start.15m"
    case keepAwake1Hour = "keepAwake.start.1h"
    case keepAwake2Hours = "keepAwake.start.2h"
    case keepAwake5Hours = "keepAwake.start.5h"
}

/// Default-browser actions exist per installed browser, so they are identified by bundle id instead of a
/// fixed case.
enum DefaultBrowserActionId {
    static let prefix = "browser.setDefault."

    static func stableId(_ bundleId: String) -> String {
        prefix + bundleId
    }

    /// One entry per bundle id, keeping the copy macOS itself would open. Updaters such as Edge's keep
    /// older copies of the same app, and a duplicate id would register the same action twice.
    static func uniqueApps(_ apps: [(bundleId: String?, path: String)], preferredPath: (String) -> String?) -> [(bundleId: String, path: String)] {
        var seen = Set<String>()
        return apps.compactMap { app -> (bundleId: String, path: String)? in
            guard let bundleId = app.bundleId, !seen.contains(bundleId) else { return nil }
            let copies = apps.filter { $0.bundleId == bundleId }.map(\.path)
            seen.insert(bundleId)
            let preferred = preferredPath(bundleId).flatMap { copies.contains($0) ? $0 : nil }
            return (bundleId, preferred ?? copies[0])
        }
    }

    /// Many apps register for web links (automation tools, chat clients, terminals). A browser also opens
    /// HTML files, which those apps do not; checked on 2026-09-16 against BetterTouchTool, ChatGPT and cmux.
    static func browserPaths(openingWebLinks web: [String], openingHtml html: Set<String>) -> [String] {
        web.filter { html.contains($0) }
    }

    static func bundleId(fromStableId stableId: String) -> String? {
        guard stableId.hasPrefix(prefix) else { return nil }
        let bundleId = String(stableId.dropFirst(prefix.count))
        return bundleId.isEmpty ? nil : bundleId
    }
}

/// Keeps the quit confirmation readable when many apps are running (story 14B).
enum QuitPrompt {
    static func names(_ names: [String], limit: Int) -> String {
        guard names.count > limit else { return names.joined(separator: ", ") }
        let shown = names.prefix(limit).joined(separator: ", ")
        return shown + " " + String(format: NSLocalizedString("and %d more", comment: ""), names.count - limit)
    }
}

extension SystemAction {
    /// Ends in `Shortcut` like every other managed shortcut key; dots are replaced so the key reads like
    /// the others in the settings file.
    var shortcutPreferenceKey: String {
        "systemAction_" + rawValue.replacingOccurrences(of: ".", with: "_") + "_Shortcut"
    }
}

// MARK: auto-quit (story 14C)

enum AutoQuitMode: Int {
    case onlyListed = 0
    case allExceptListed = 1
}

struct AutoQuitRules: Equatable {
    var mode: AutoQuitMode
    var bundleIds: Set<String>
}

enum AutoQuitPolicy {
    static let neverQuit: Set<String> = ["com.apple.finder"]

    static func applies(_ bundleId: String?, rules: AutoQuitRules, isRegular: Bool, isSelf: Bool) -> Bool {
        guard let bundleId, isRegular, !isSelf, !neverQuit.contains(bundleId) else { return false }
        let listed = rules.bundleIds.contains(bundleId)
        return rules.mode == .onlyListed ? listed : !listed
    }

    /// Whether a window still keeps its app alive. Music and Cisco Secure Client do not destroy a window on
    /// the red button; they order it out, and it then sits on no Space and off screen (measured 2026-09-17).
    /// A minimized window keeps its Space, and a hidden app keeps its windows, so neither counts as closed.
    static func windowCountsAsOpen(isMinimized: Bool, appIsHidden: Bool, isOnAnySpace: Bool, isOnScreen: () -> Bool) -> Bool {
        isMinimized || appIsHidden || isOnAnySpace || isOnScreen()
    }

    /// Re-checked when the delay ends: a new window or the user coming back to the app cancels it.
    /// An app with its own menu bar item keeps running without windows on purpose (a password manager, a
    /// container runtime), so quitting it would take the item away.
    /// `quitsDespiteMenuBarItem` is the user's own list of such apps that should quit anyway (Outlook, say).
    static func shouldQuitNow(hasWindows: Bool, isFrontmost: Bool, isTerminated: Bool, hasMenuBarItems: Bool,
                              quitsDespiteMenuBarItem: Bool = false) -> Bool {
        !hasWindows && !isFrontmost && !isTerminated && (!hasMenuBarItems || quitsDespiteMenuBarItem)
    }

    static func decodeList(_ raw: String) -> [String] {
        guard let data = raw.data(using: .utf8), let list = try? JSONDecoder().decode([String].self, from: data) else { return [] }
        return list
    }

    static func encodeList(_ list: [String]) -> String {
        guard let data = try? JSONEncoder().encode(list) else { return "[]" }
        return String(data: data, encoding: .utf8) ?? "[]"
    }
}

// MARK: cat mode (story 14K)

/// Recognises the typed word that ends Cat Mode. Case-insensitive; any other key restarts the match, and
/// a wrong key that is itself the first letter starts a new attempt.
struct UnlockSequenceMatcher {
    static let word = Array("unlock")
    private(set) var matched = 0

    mutating func feed(_ character: Character) -> Bool {
        let lowered = Character(character.lowercased())
        if lowered == Self.word[matched] {
            matched += 1
        } else {
            matched = lowered == Self.word[0] ? 1 : 0
        }
        guard matched == Self.word.count else { return false }
        matched = 0
        return true
    }
}

enum CatModePanic {
    static let escapeKeyCode: Int64 = 53
    static let requiredFlags: UInt64 = (1 << 17) | (1 << 18) | (1 << 19) | (1 << 20)

    /// The emergency shortcut is a Carbon hot key, which never fires while Cat Mode swallows keys at the HID
    /// level, so the tap recognises it itself (Q-01).
    static func isEmergencyShortcut(keyCode: Int64, flags: UInt64) -> Bool {
        keyCode == escapeKeyCode && flags & requiredFlags == requiredFlags
    }
}

/// The microphone key sends a dictation usage that macOS handles before any event tap sees it. AltTab+
/// remaps it to F17 through the HID `UserKeyMapping` property; no Apple keyboard has F17, so the remap takes
/// no key away, and F17 then arrives in the event tap like any other key.
enum MicKeyMapping {
    static let sourceKey = "HIDKeyboardModifierMappingSrc"
    static let destinationKey = "HIDKeyboardModifierMappingDst"
    /// Consumer page 0x0C, usage 0xCF "Voice Command": the microphone key in the F5 position.
    static let microphoneKey: UInt64 = 0xC000000CF
    /// Keyboard page 0x07, usage 0x6C: F17.
    static let f17: UInt64 = 0x70000006C

    /// Other mappings stay; an earlier mapping of the microphone key is replaced, not duplicated.
    static func adding(_ mappings: [[String: UInt64]]) -> [[String: UInt64]] {
        mappings.filter { $0[sourceKey] != microphoneKey } + [[sourceKey: microphoneKey, destinationKey: f17]]
    }

    /// Removes only the mapping AltTab+ made, so a remap another tool made to some other key survives.
    static func removing(_ mappings: [[String: UInt64]]) -> [[String: UInt64]] {
        mappings.filter { !($0[sourceKey] == microphoneKey && $0[destinationKey] == f17) }
    }
}
