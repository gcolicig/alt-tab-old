import Foundation

/// Every built-in action added from the Supercharge comparison (stories 10, 12, 14). The raw value is the
/// persisted `stableId`, so Leader and FlickRing bindings survive renames of the Swift case.
enum SystemAction: String, CaseIterable {
    case isolateWindow = "windowFocus.isolate"
    case minimizeAppOthers = "windowFocus.minimizeAppOthers"
    case hideOtherApps = "windowFocus.hideOthers"
    case minimizeAllOthers = "windowFocus.minimizeAllOthers"
    case minimizeAll = "windowFocus.minimizeAll"
    case hideAll = "windowFocus.hideAll"
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
    case settingsVpn = "settingsJump.vpn"
    case settingsHideMyEmail = "settingsJump.hideMyEmail"
    case settingsPrivateRelay = "settingsJump.privateRelay"
    case settingsIphoneNotifications = "settingsJump.iphoneNotifications"
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

    /// Story 12b marks these as optional; they exist but stay out of the menu until the user shows them.
    var visibleInMenuByDefault: Bool {
        ![.minimizeAllOthers, .minimizeAll, .hideAll, .keepAwakeStop, .keepAwakeIndefinitely, .keepAwake15Minutes,
          .keepAwake1Hour, .keepAwake2Hours, .keepAwake5Hours, .keepAwakeToggle].contains(self)
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

    /// Re-checked when the delay ends: a new window or the user coming back to the app cancels it.
    static func shouldQuitNow(hasWindows: Bool, isFrontmost: Bool, isTerminated: Bool) -> Bool {
        !hasWindows && !isFrontmost && !isTerminated
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
