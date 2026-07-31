import Foundation

/// The two pointer scaling values live in `NSGlobalDomain`, verified present on macOS 26.5.1 as
/// `com.apple.mouse.scaling` and `com.apple.trackpad.scaling`. CFPreferences against
/// `kCFPreferencesAnyApplication` is the structured equivalent of `defaults write -g`: no shell process,
/// no IOKit, no private API and no additional TCC permission.
///
/// Writing here changes global system state for the whole login session, which is why no call site may
/// reach these functions without going through `PointerOwnership` first.
enum PointerSystemSettings {
    static func read(_ category: PointerCategory) -> Double? {
        let value = CFPreferencesCopyValue(category.scalingKey as CFString, kCFPreferencesAnyApplication, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        guard let number = value as? NSNumber else { return nil }
        return number.doubleValue
    }

    /// Returns the canonical value the system actually stored, which is not necessarily what was asked
    /// for: the read-back is what ownership is tracked against.
    static func write(_ category: PointerCategory, _ value: Double) -> Double? {
        CFPreferencesSetValue(category.scalingKey as CFString, value as CFNumber, kCFPreferencesAnyApplication, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        guard CFPreferencesSynchronize(kCFPreferencesAnyApplication, kCFPreferencesCurrentUser, kCFPreferencesAnyHost) else { return nil }
        return read(category)
    }
}
