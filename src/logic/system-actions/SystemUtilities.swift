import Cocoa
import IOKit
import Carbon.HIToolbox

/// Story 14D, 14F, 14G: actions with no state of their own.
enum SystemUtilities {
    static func clearClipboard() {
        NSPasteboard.general.clearContents()
        TransientNotice.show(NSLocalizedString("Clipboard cleared.", comment: ""))
    }

    // MARK: paste and match style

    /// Apps differ in how they handle the system Paste and Match Style (some ignore it), so the clipboard
    /// is reduced to its plain text, a Cmd-V goes to the frontmost app, and the original contents come back.
    static func plainPasteAvailability() -> ActionAvailability {
        NSPasteboard.general.string(forType: .string) == nil ? .unavailable(NSLocalizedString("The clipboard holds no text.", comment: "")) : .available
    }

    static func pasteAsPlainText() {
        let pasteboard = NSPasteboard.general
        guard let text = pasteboard.string(forType: .string) else { return NSSound.beep() }
        let original = snapshot(pasteboard)
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        let plainChangeCount = pasteboard.changeCount
        // the delay lets the menubar menu close first, so the key event reaches the app behind it
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            postCommandV()
            // restored late enough for the target app to read the plain text; skipped if anything else wrote
            // to the clipboard meanwhile, so a newer copy is never overwritten
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                guard pasteboard.changeCount == plainChangeCount else { return }
                pasteboard.clearContents()
                pasteboard.writeObjects(original)
            }
        }
    }

    private static func snapshot(_ pasteboard: NSPasteboard) -> [NSPasteboardItem] {
        (pasteboard.pasteboardItems ?? []).map { item in
            let copy = NSPasteboardItem()
            item.types.forEach { type in
                if let data = item.data(forType: type) { copy.setData(data, forType: type) }
            }
            return copy
        }
    }

    /// Explicit flags, so modifiers the user still holds from the triggering shortcut do not change the key.
    private static func postCommandV() {
        guard let source = CGEventSource(stateID: .hidSystemState) else { return NSSound.beep() }
        for keyDown in [true, false] {
            guard let event = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: keyDown) else { return NSSound.beep() }
            event.flags = .maskCommand
            event.post(tap: .cgSessionEventTap)
        }
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
