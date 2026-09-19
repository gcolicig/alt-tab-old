import Cocoa
import ShortcutRecorder

/// Whether a shortcut recorder's current value differs from its registered default — including the
/// "cleared" case, where one side is unassigned (`nil`) and the other isn't. Drives whether the
/// recorder's "Restore default" button shows.
enum ShortcutDefault {
    static func differsFromDefault(_ current: Shortcut?, _ defaultShortcut: Shortcut?) -> Bool {
        switch (current, defaultShortcut) {
            case (nil, nil): return false
            case (nil, _), (_, nil): return true
            case let (current?, defaultShortcut?):
                return current.carbonKeyCode != defaultShortcut.carbonKeyCode || current.carbonModifierFlags != defaultShortcut.carbonModifierFlags
        }
    }
}
