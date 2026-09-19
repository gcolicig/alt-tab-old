import Foundation
import IOKit
import IOKit.hid

/// Story 14J. `HIDFKeyMode` through the HID system: 1 means F1-F12 act as standard function keys. The read
/// path and a same-value write were checked on 2026-09-16 (macOS 26.6); whether a changed value takes
/// effect at once is V-20. The preference is written as well so the choice survives a restart, the same
/// place System Settings keeps it.
///
/// Ownership follows story 4 in reduced form: the value from before the first toggle is kept, and turning
/// the module off gives it back unless something else changed the value meanwhile.
enum FunctionKeys {
    private static let preferenceKey = "com.apple.keyboard.fnState"
    private static let baselineKey = "functionKeysBaseline"
    private static let lastWrittenKey = "functionKeysLastWritten"

    static func isStandard() -> Bool? {
        withConnection { connection in
            var value: Unmanaged<CFTypeRef>?
            guard IOHIDCopyCFTypeParameter(connection, kIOHIDFKeyModeKey as CFString, &value) == KERN_SUCCESS,
                  let number = value?.takeRetainedValue() as? NSNumber else { return nil }
            return number.intValue == 1
        }
    }

    static func toggle() {
        guard let current = isStandard() else { return NSSound.beep() }
        if UserDefaults.standard.object(forKey: baselineKey) == nil {
            UserDefaults.standard.set(current, forKey: baselineKey)
        }
        write(!current)
    }

    /// Only hands the baseline back when the system still holds what AltTab+ wrote last.
    static func releaseOwnership() {
        guard let baseline = UserDefaults.standard.object(forKey: baselineKey) as? Bool else { return }
        if let lastWritten = UserDefaults.standard.object(forKey: lastWrittenKey) as? Bool, isStandard() == lastWritten {
            write(baseline)
        }
        UserDefaults.standard.removeObject(forKey: baselineKey)
        UserDefaults.standard.removeObject(forKey: lastWrittenKey)
    }

    private static func write(_ standard: Bool) {
        let applied: Bool? = withConnection { connection in
            IOHIDSetCFTypeParameter(connection, kIOHIDFKeyModeKey as CFString, NSNumber(value: standard ? 1 : 0)) == KERN_SUCCESS
        }
        guard applied == true, isStandard() == standard else {
            return TransientNotice.show(NSLocalizedString("The function key mode could not be changed.", comment: ""))
        }
        UserDefaults.standard.set(standard, forKey: lastWrittenKey)
        CFPreferencesSetValue(preferenceKey as CFString, standard as CFBoolean, kCFPreferencesAnyApplication, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        CFPreferencesSynchronize(kCFPreferencesAnyApplication, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
    }

    private static func withConnection<T>(_ body: (io_connect_t) -> T?) -> T? {
        let service = IOServiceGetMatchingService(0, IOServiceMatching(kIOHIDSystemClass))
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }
        var connection = io_connect_t(0)
        guard IOServiceOpen(service, mach_task_self_, UInt32(kIOHIDParamConnectType), &connection) == KERN_SUCCESS else { return nil }
        defer { IOServiceClose(connection) }
        return body(connection)
    }
}

/// The global `ApplePressAndHoldEnabled` preference: on (the macOS default) shows the accent popup while a
/// letter key is held, off repeats the key instead. Apps read it once at launch, so a change only reaches
/// apps started afterwards.
enum PressAndHold {
    private static let preferenceKey = "ApplePressAndHoldEnabled" as CFString

    static func isEnabled() -> Bool {
        CFPreferencesCopyValue(preferenceKey, kCFPreferencesAnyApplication, kCFPreferencesCurrentUser, kCFPreferencesAnyHost) as? Bool ?? true
    }

    static func toggle() {
        let enabled = !isEnabled()
        CFPreferencesSetValue(preferenceKey, enabled as CFBoolean, kCFPreferencesAnyApplication, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        guard CFPreferencesSynchronize(kCFPreferencesAnyApplication, kCFPreferencesCurrentUser, kCFPreferencesAnyHost), isEnabled() == enabled else {
            return TransientNotice.show(NSLocalizedString("Press and Hold could not be changed.", comment: ""))
        }
        TransientNotice.show(enabled
            ? NSLocalizedString("Holding a key now shows accents. Restart an app to apply it there.", comment: "")
            : NSLocalizedString("Holding a key now repeats it. Restart an app to apply it there.", comment: ""))
    }
}
