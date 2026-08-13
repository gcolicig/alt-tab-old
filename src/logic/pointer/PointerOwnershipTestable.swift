import Foundation

/// Pointer scaling is global system state, so AltTab+ may only write it while it provably still owns the
/// value it last wrote. Every decision below is pure: the caller supplies the persisted record and the value
/// currently in the system, and gets back what to do. Nothing here reads defaults or touches the system.
enum PointerCategory: String, CaseIterable {
    case mouse
    case trackpad

    /// The HID system's acceleration key, which is where the value the pointer actually follows lives.
    /// The `NSGlobalDomain` keys `com.apple.mouse.scaling` and `com.apple.trackpad.scaling` mirror it but
    /// writing them was measured on 2026-08-07 to change nothing in the running session.
    var accelerationKey: String {
        switch self {
            case .mouse: return "HIDMouseAcceleration"
            case .trackpad: return "HIDTrackpadAcceleration"
        }
    }
}

/// macOS exposes tracking speed as a discrete slider, not a free value, and the scaling numbers behind its
/// notches are what a restore has to be able to reproduce. Storing the notch index keeps the preference an
/// integer, which is what the settings slider binds to, while the value written to the system stays exact.
enum PointerSpeedSteps {
    static let values = [0.0, 0.125, 0.3125, 0.5, 0.6875, 0.875, 1.0, 1.5, 2.0, 2.5, 3.0]

    static var maximumIndex: Int { values.count - 1 }

    static func value(_ index: Int) -> Double {
        values[min(max(index, 0), maximumIndex)]
    }

    /// Used when taking ownership of a value the system already holds, which need not sit on a notch.
    static func nearestIndex(_ value: Double) -> Int {
        values.enumerated().min { abs($0.element - value) < abs($1.element - value) }?.offset ?? 0
    }
}

/// The ownership model now lives in `SystemValueOwnership`, shared with the modifier drag's ownership of
/// `NSWindowShouldDragOnGesture`. These aliases keep the pointer call sites and their tests unchanged.
typealias PointerOwnershipState = SystemValueOwnershipState
typealias PointerOwnershipRecord = SystemValueOwnershipRecord<Double>
typealias PointerReapplyDecision = SystemValueReapplyDecision<Double>
typealias PointerDisableDecision = SystemValueDisableDecision<Double>
typealias PointerRecoveryDecision = SystemValueRecoveryDecision<Double>
typealias PointerOwnershipPolicy = SystemValueOwnership<Double>

/// macOS encodes both settings in the one scaling value: a negative value turns acceleration off, any
/// positive value is the pointer speed. So the two settings from the backlog map onto a single number,
/// and `systemDefault` means AltTab+ owns nothing at all rather than writing some neutral value.
enum PointerAccelerationMode: String, Codable {
    case systemDefault
    case disabled
    case custom

    /// Acceleration off, as the HID system expresses it. This was `-1.0` while the module wrote
    /// `com.apple.mouse.scaling`, where a negative value carried that meaning. `IOHIDSetAccelerationWithKey`
    /// does not use that convention: measured on 2026-08-10, it clamps every negative input to `0` and still
    /// reports `KERN_SUCCESS`. The read-back then disagreed with the write, so picking `Disabled` moved the
    /// pointer and refused ownership in the same step — see V-10.
    static let accelerationDisabledValue = 0.0

    func desiredValue(speed: Double) -> Double? {
        switch self {
            case .systemDefault: return nil
            case .disabled: return PointerAccelerationMode.accelerationDisabledValue
            case .custom: return speed
        }
    }
}

