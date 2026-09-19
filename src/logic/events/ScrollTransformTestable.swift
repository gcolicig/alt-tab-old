import Foundation

/// Discrete scroll speed multipliers. Kept small and fixed for the MVP — no custom curves. `normal` is 1.0,
/// which makes the whole transform a no-op so the tap can leave the event untouched.
enum ScrollSpeedPreference: String, CaseIterable {
    case half
    case normal
    case double
    case triple
    case quadruple
    case quintuple

    var factor: Double {
        switch self {
            case .half: return 0.5
            case .normal: return 1.0
            case .double: return 2.0
            case .triple: return 3.0
            case .quadruple: return 4.0
            case .quintuple: return 5.0
        }
    }
}

/// One scroll category's settings (mouse or trackpad): reverse the vertical axis, and a speed multiplier.
struct ScrollAxisSettings: Equatable {
    var reverseVertical: Bool
    var speed: Double

    init(reverseVertical: Bool = false, speed: Double = 1.0) {
        self.reverseVertical = reverseVertical
        self.speed = speed
    }
}

/// Pure scroll math. The tap reads the event's fields, asks here for the factor to apply to each axis, and
/// writes them back. macOS exposes only one global natural-scrolling switch, so separate mouse/trackpad
/// direction is only reachable by rewriting the event — which is why this runs in a tap at all.
enum ScrollTransform {
    /// Continuous events come from a trackpad or a Magic Mouse; discrete events from a classic wheel.
    static func settings(isContinuous: Bool, mouse: ScrollAxisSettings, trackpad: ScrollAxisSettings) -> ScrollAxisSettings {
        isContinuous ? trackpad : mouse
    }

    static func verticalFactor(_ settings: ScrollAxisSettings) -> Double {
        (settings.reverseVertical ? -1 : 1) * settings.speed
    }

    static func horizontalFactor(_ settings: ScrollAxisSettings) -> Double {
        settings.speed
    }

    /// True when applying these settings would change the event. When neither category modifies anything, no
    /// tap needs to run for scrolling at all.
    static func modifies(_ settings: ScrollAxisSettings) -> Bool {
        settings.reverseVertical || settings.speed != 1.0
    }

    static func anyModifies(mouse: ScrollAxisSettings, trackpad: ScrollAxisSettings) -> Bool {
        modifies(mouse) || modifies(trackpad)
    }
}
