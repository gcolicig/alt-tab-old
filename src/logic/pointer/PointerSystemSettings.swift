import Foundation
import IOKit

/// The two pointer scaling values as the system actually applies them, read and written through the HID
/// system rather than through a preference.
///
/// This used to write `com.apple.mouse.scaling` and `com.apple.trackpad.scaling` in `NSGlobalDomain`
/// through CFPreferences. That path was chosen because the values could be *read* there, and measuring
/// on 2026-08-07 showed the inference was wrong: writing the preference set the preference and left the
/// pointer untouched. Worse, the module could not tell — it checked its own success by reading back the
/// preference it had just written, which always succeeds, so it reported `managed` while nothing had
/// changed. `IOHIDSetAccelerationWithKey` moves the effective value immediately, and
/// `IOHIDGetAccelerationWithKey` reports it, which also means a value is always readable: the earlier
/// case of a machine where the preference had never been written no longer exists.
///
/// The setting does **not** survive, measured 2026-08-10 (S-12): a value armed at 0.875 read back as
/// 0.6875 after a restart, and had already fallen back once during the preceding session. Re-applying
/// after launch and after wake is the follow-up, not writing the preference again — the preference was
/// absent the whole time and that did not stop the effective value from being set.
///
/// The symbols are resolved at runtime rather than called directly. They are deprecated since 10.12 and
/// the build treats warnings as errors, and per V-03 a symbol that may disappear degrades to "feature
/// unavailable" instead of a build or launch failure.
///
/// Writing here changes global system state for the whole login session, which is why no call site may
/// reach these functions without going through `PointerOwnership` first.
enum PointerSystemSettings {
    private typealias OpenEventStatusFunction = @convention(c) () -> io_connect_t
    private typealias CloseEventStatusFunction = @convention(c) (io_connect_t) -> Void
    private typealias GetAccelerationFunction = @convention(c) (io_connect_t, CFString, UnsafeMutablePointer<Double>) -> IOReturn
    private typealias SetAccelerationFunction = @convention(c) (io_connect_t, CFString, Double) -> IOReturn

    private static let openEventStatus: OpenEventStatusFunction? = resolve("NXOpenEventStatus")
    private static let closeEventStatus: CloseEventStatusFunction? = resolve("NXCloseEventStatus")
    private static let getAcceleration: GetAccelerationFunction? = resolve("IOHIDGetAccelerationWithKey")
    private static let setAcceleration: SetAccelerationFunction? = resolve("IOHIDSetAccelerationWithKey")

    static var isAvailable: Bool {
        openEventStatus != nil && closeEventStatus != nil && getAcceleration != nil && setAcceleration != nil
    }

    static func read(_ category: PointerCategory) -> Double? {
        withConnection { connection in
            guard let getAcceleration else { return nil }
            var value = Double(0)
            guard getAcceleration(connection, category.accelerationKey as CFString, &value) == KERN_SUCCESS else { return nil }
            return value
        }
    }

    /// Returns the value the system actually holds afterwards, which is not necessarily what was asked
    /// for: the read-back is what ownership is tracked against. It is a second, independent query rather
    /// than an echo of the argument, so a write that is accepted and ignored cannot pass for success.
    static func write(_ category: PointerCategory, _ value: Double) -> Double? {
        let applied: Bool? = withConnection { connection in
            guard let setAcceleration else { return nil }
            return setAcceleration(connection, category.accelerationKey as CFString, value) == KERN_SUCCESS
        }
        guard applied == true else { return nil }
        return read(category)
    }

    /// Each call opens and closes its own connection. Holding one open across the app's lifetime would
    /// keep a handle on the event status driver for a feature that is touched a handful of times.
    private static func withConnection<T>(_ body: (io_connect_t) -> T?) -> T? {
        guard let openEventStatus, let closeEventStatus else { return nil }
        let connection = openEventStatus()
        guard connection != 0 else { return nil }
        defer { closeEventStatus(connection) }
        return body(connection)
    }

    private static func resolve<T>(_ name: String) -> T? {
        guard let symbol = dlsym(UnsafeMutableRawPointer(bitPattern: -2), name) else { return nil }
        return unsafeBitCast(symbol, to: T.self)
    }
}
