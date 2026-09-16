import Cocoa
import IOKit

/// Story 14A, 14D, 14F, 14G: actions with no state of their own.
enum SystemUtilities {
    /// Anchors verified 2026-09-16 on macOS 26.6 by reading the settings extensions' Info.plist: each
    /// declares `allowsXAppleSystemPreferencesURLScheme`. Hide My Email and Private Relay have no anchor of
    /// their own; they open the iCloud scene, where both live.
    static func settingsUrl(_ action: SystemAction) -> URL? {
        switch action {
            case .settingsVpn: return URL(string: "x-apple.systempreferences:com.apple.NetworkExtensionSettingsUI.NESettingsUIExtension")
            case .settingsHideMyEmail, .settingsPrivateRelay: return URL(string: "x-apple.systempreferences:com.apple.systempreferences.AppleIDSettings:icloud")
            case .settingsIphoneNotifications: return URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension")
            default: return nil
        }
    }

    static func openSettings(_ action: SystemAction) {
        guard let url = settingsUrl(action) else { return }
        NSWorkspace.shared.open(url)
    }

    static func clearClipboard() {
        NSPasteboard.general.clearContents()
        TransientNotice.show(NSLocalizedString("Clipboard cleared.", comment: ""))
    }

    // MARK: eject

    static func ejectableVolumes() -> [URL] {
        let keys: [URLResourceKey] = [.volumeIsEjectableKey, .volumeIsRemovableKey, .volumeIsInternalKey, .volumeIsLocalKey]
        let volumes = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: keys, options: [.skipHiddenVolumes]) ?? []
        return volumes.filter(isEjectable)
    }

    private static func isEjectable(_ url: URL) -> Bool {
        guard url.path != "/", let values = try? url.resourceValues(forKeys: [.volumeIsEjectableKey, .volumeIsRemovableKey, .volumeIsInternalKey, .volumeIsLocalKey]) else { return false }
        if values.volumeIsLocal == false { return true }
        return (values.volumeIsEjectable == true || values.volumeIsRemovable == true) && values.volumeIsInternal != true
    }

    static func ejectAllDisks() {
        let volumes = ejectableVolumes()
        guard !volumes.isEmpty else { return NSSound.beep() }
        DispatchQueue.global(qos: .userInitiated).async {
            let busy = volumes.filter { !eject($0) }.map { $0.lastPathComponent }
            DispatchQueue.main.async { announceEject(ejected: volumes.count - busy.count, busy: busy) }
        }
    }

    private static func eject(_ url: URL) -> Bool {
        do {
            try NSWorkspace.shared.unmountAndEjectDevice(at: url)
            return true
        } catch {
            Logger.warning { "Eject failed for \(url.lastPathComponent): \(error)" }
            return false
        }
    }

    private static func announceEject(ejected: Int, busy: [String]) {
        let base = String(format: NSLocalizedString("Ejected %d disk(s).", comment: ""), ejected)
        guard !busy.isEmpty else { return TransientNotice.show(base) }
        TransientNotice.show(base + " " + String(format: NSLocalizedString("Still in use: %@.", comment: ""), busy.joined(separator: ", ")))
    }

    // MARK: display sleep

    /// Delayed so releasing the triggering key does not wake the displays at once.
    static func sleepDisplays() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            DispatchQueue.global(qos: .userInitiated).async {
                guard !sleepDisplaysWithPmset(), !sleepDisplaysWithWrangler() else { return }
                DispatchQueue.main.async { TransientNotice.show(NSLocalizedString("The displays could not be put to sleep.", comment: "")) }
            }
        }
    }

    private static func sleepDisplaysWithPmset() -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        process.arguments = ["displaysleepnow"]
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            Logger.warning { "pmset displaysleepnow failed: \(error)" }
            return false
        }
    }

    private static func sleepDisplaysWithWrangler() -> Bool {
        let entry = IORegistryEntryFromPath(kIOMainPortDefault, "IOService:/IOResources/IODisplayWrangler")
        guard entry != 0 else { return false }
        defer { IOObjectRelease(entry) }
        return IORegistryEntrySetCFProperty(entry, "IORequestIdle" as CFString, kCFBooleanTrue) == KERN_SUCCESS
    }
}
