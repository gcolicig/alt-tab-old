import CoreGraphics
import Foundation

/// The four directions the ring can point. `right` is the +x axis and the rest follow counter-clockwise,
/// matching `atan2`. `CaseIterable` gives the settings editor and the overlay one source for the sectors.
enum FlickDirection: String, CaseIterable, Codable {
    case up
    case right
    case down
    case left
}

/// Pure geometry for the ring: which sector a drag points at, and whether it cleared the dead zone. The
/// event tap only ever calls this; picking and running the bound action happens off the callback (Q-16).
enum FlickRing {
    /// Below this cursor distance from the press point no direction is chosen and nothing runs. Matches the
    /// template (`mikker/FlickRing`), where a 5pt dead zone keeps a plain click from firing a direction.
    static let deadZone: CGFloat = 5

    /// `dx`/`dy` are measured from the ring centre with +y pointing up (math convention), so the tap must
    /// flip the screen delta whose y grows downward. Returns nil inside the dead zone: a short press is a
    /// no-op, and the overlay shows that rather than letting it read as a swallowed click.
    static func direction(dx: CGFloat, dy: CGFloat, deadZone: CGFloat = deadZone) -> FlickDirection? {
        guard hypot(dx, dy) >= deadZone else { return nil }
        // atan2 returns -180…180 degrees, 0 at +x (right) and +90 at +y (up)
        let degrees = atan2(dy, dx) * 180 / .pi
        switch degrees {
            case -45 ..< 45: return .right
            case 45 ..< 135: return .up
            case -135 ..< -45: return .down
            default: return .left
        }
    }
}
