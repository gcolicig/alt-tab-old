import Foundation

/// Pointer scaling is global system state, so AltTab+ may only write it while it provably still owns the
/// value it last wrote. Every decision below is pure: the caller supplies the persisted record and the value
/// currently in the system, and gets back what to do. Nothing here reads defaults or touches the system.
enum PointerCategory: String, CaseIterable {
    case mouse
    case trackpad

    /// The scaling key in NSGlobalDomain. Verified present on macOS 26.5.1 (build 25F80).
    var scalingKey: String {
        switch self {
            case .mouse: return "com.apple.mouse.scaling"
            case .trackpad: return "com.apple.trackpad.scaling"
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

    static let accelerationDisabledValue = -1.0

    func desiredValue(speed: Double) -> Double? {
        switch self {
            case .systemDefault: return nil
            case .disabled: return PointerAccelerationMode.accelerationDisabledValue
            case .custom: return speed
        }
    }
}

