import Cocoa

/// One row per built-in action from stories 10, 12 and 14: how it is named, where it sits in the menubar
/// menu, what it does, and whether it can run right now. Menu, shortcuts, Leader and FlickRing all go
/// through `Actions`, which reads this table (SA-01).
struct SystemActionSpec {
    let action: SystemAction
    let title: String
    let symbol: String
    let group: MenuGroup
    let perform: () -> Void
    let availability: () -> ActionAvailability
    let isOn: (() -> Bool)?
}

enum SystemActions {
    static let all: [SystemActionSpec] = {
        var specs = [SystemActionSpec]()
        [windowActions, appActions, toolActions, notificationActions, systemActions, toggleActions, keepAwakeActions].forEach { specs.append(contentsOf: $0) }
        return specs
    }()

    static func spec(_ action: SystemAction) -> SystemActionSpec? {
        byAction[action]
    }

    private static let byAction = Dictionary(uniqueKeysWithValues: all.map { ($0.action, $0) })

    private static func make(_ action: SystemAction, _ title: String, _ symbol: String, _ group: MenuGroup,
                             availability: @escaping () -> ActionAvailability = { .available }, isOn: (() -> Bool)? = nil,
                             _ perform: @escaping () -> Void) -> SystemActionSpec {
        SystemActionSpec(action: action, title: title, symbol: symbol, group: group, perform: perform, availability: availability, isOn: isOn)
    }

    private static let windowActions: [SystemActionSpec] = [
        make(.isolateWindow, NSLocalizedString("Isolate Window", comment: ""), "macwindow", .windows, availability: WindowFocusActions.availability) { WindowFocusActions.perform(.isolateWindow) },
        make(.minimizeAppOthers, NSLocalizedString("Minimize App Windows Except Frontmost", comment: ""), "macwindow.stack", .windows, availability: WindowFocusActions.availability) { WindowFocusActions.perform(.minimizeAppOthers) },
        make(.hideOtherApps, NSLocalizedString("Hide Other Apps", comment: ""), "eye.slash", .windows, availability: WindowFocusActions.availability) { WindowFocusActions.perform(.hideOtherApps) },
        make(.hideAll, NSLocalizedString("Hide All Windows", comment: ""), "eye.slash.circle", .windows, availability: WindowFocusActions.availability) { WindowFocusActions.perform(.hideAll) },
    ]

    private static let appActions: [SystemActionSpec] = [
        make(.quitAllApps, NSLocalizedString("Quit All Apps…", comment: ""), "xmark.circle", .apps) { AppQuit.quitAll(keepingFrontmost: false) },
        make(.quitAllAppsExceptFrontmost, NSLocalizedString("Quit All Apps Except Frontmost…", comment: ""), "xmark.circle.fill", .apps) { AppQuit.quitAll(keepingFrontmost: true) },
    ]

    private static let toolActions: [SystemActionSpec] = [
        make(.pickColor, NSLocalizedString("Pick Color", comment: ""), "eyedropper", .tools) { ScreenTools.pickColor() },
        make(.captureText, NSLocalizedString("Capture Text", comment: ""), "text.viewfinder", .tools, availability: ScreenTools.captureAvailability) { ScreenTools.captureText() },
        make(.captureTranslate, NSLocalizedString("Capture & Translate", comment: ""), "character.bubble", .tools, availability: ScreenTools.translateAvailability) { ScreenTools.captureTranslate() },
        make(.scanQr, NSLocalizedString("Scan QR Code", comment: ""), "qrcode.viewfinder", .tools, availability: ScreenTools.captureAvailability) { ScreenTools.scanQr() },
        make(.scanQrClipboard, NSLocalizedString("Scan QR Code from Clipboard", comment: ""), "doc.on.clipboard", .tools, availability: ScreenTools.clipboardImageAvailability) { ScreenTools.scanQrFromClipboard() },
    ]

    private static let notificationActions: [SystemActionSpec] = [
        make(.clearVisibleNotifications, NSLocalizedString("Clear Visible Notifications", comment: ""), "bell.slash", .notifications, availability: NotificationActions.availability) { NotificationActions.clear(all: false) },
        make(.clearAllNotifications, NSLocalizedString("Clear All Notifications", comment: ""), "bell.badge.slash", .notifications, availability: NotificationActions.availability) { NotificationActions.clear(all: true) },
    ]

    private static let systemActions: [SystemActionSpec] = [
        make(.clearClipboard, NSLocalizedString("Clear Clipboard", comment: ""), "clipboard", .system) { SystemUtilities.clearClipboard() },
        make(.ejectAllDisks, NSLocalizedString("Eject All Disks", comment: ""), "eject", .system, availability: ejectAvailability) { SystemUtilities.ejectAllDisks() },
        make(.sleepDisplays, NSLocalizedString("Sleep Displays", comment: ""), "moon", .system) { SystemUtilities.sleepDisplays() },
    ]

    private static let toggleActions: [SystemActionSpec] = [
        make(.muteOutputToggle, NSLocalizedString("Mute Sound", comment: ""), "speaker.slash", .toggles,
             availability: { audioAvailability(input: false) }, isOn: { AudioMute.isMuted(input: false) }) { AudioMute.toggle(input: false) },
        make(.muteInputToggle, NSLocalizedString("Mute Microphone", comment: ""), "mic.slash", .toggles,
             availability: { audioAvailability(input: true) }, isOn: { AudioMute.isMuted(input: true) }) { AudioMute.toggle(input: true) },
        make(.functionKeysToggle, NSLocalizedString("Function Keys", comment: ""), "fn", .toggles,
             availability: functionKeysAvailability, isOn: { FunctionKeys.isStandard() == true }) { FunctionKeys.toggle() },
        make(.autoQuitToggle, NSLocalizedString("Auto-Quit Apps", comment: ""), "power", .toggles, isOn: { Preferences.autoQuitEnabled }) { AutoQuit.toggle() },
        make(.catModeToggle, NSLocalizedString("Cat Mode", comment: ""), "cat", .toggles, availability: CatMode.availability, isOn: { CatMode.isOn }) { CatMode.toggle() },
    ]

    /// Reachable from shortcuts, Leader and FlickRing; the menu shows them inside the Keep Awake submenu.
    private static let keepAwakeActions: [SystemActionSpec] = [
        make(.keepAwakeToggle, NSLocalizedString("Keep Awake", comment: ""), "cup.and.saucer", .toggles, isOn: { KeepAwake.isActive }) { KeepAwake.toggle() },
        make(.keepAwakeStop, NSLocalizedString("Stop Keeping Awake", comment: ""), "stop.circle", .toggles) { KeepAwake.stop(reason: nil) },
        make(.keepAwakeIndefinitely, NSLocalizedString("Keep Awake Indefinitely", comment: ""), "infinity", .toggles) { KeepAwake.start(.indefinitely) },
        make(.keepAwake15Minutes, NSLocalizedString("Keep Awake for 15 Minutes", comment: ""), "clock", .toggles) { KeepAwake.start(.minutes15) },
        make(.keepAwake1Hour, NSLocalizedString("Keep Awake for 1 Hour", comment: ""), "clock", .toggles) { KeepAwake.start(.hour1) },
        make(.keepAwake2Hours, NSLocalizedString("Keep Awake for 2 Hours", comment: ""), "clock", .toggles) { KeepAwake.start(.hours2) },
        make(.keepAwake5Hours, NSLocalizedString("Keep Awake for 5 Hours", comment: ""), "clock", .toggles) { KeepAwake.start(.hours5) },
    ]

    private static func ejectAvailability() -> ActionAvailability {
        SystemUtilities.ejectableVolumes().isEmpty ? .unavailable(NSLocalizedString("No ejectable disks.", comment: "")) : .available
    }

    private static func audioAvailability(input: Bool) -> ActionAvailability {
        AudioMute.isAvailable(input: input) ? .available : .unavailable(NSLocalizedString("The audio device cannot be muted.", comment: ""))
    }

    private static func functionKeysAvailability() -> ActionAvailability {
        FunctionKeys.isStandard() == nil ? .unavailable(NSLocalizedString("The function key mode cannot be read.", comment: "")) : .available
    }
}
