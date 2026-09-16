import CoreGraphics
import Foundation

enum ScreenToolsFormat {
    /// `#RRGGBB` from sRGB components in 0...1.
    static func hex(red: Double, green: Double, blue: Double) -> String {
        String(format: "#%02X%02X%02X", byte(red), byte(green), byte(blue))
    }

    private static func byte(_ component: Double) -> Int {
        Int((min(max(component, 0), 1) * 255).rounded())
    }

    /// A scanned code is only offered for opening when it is a web or mail link; it is never opened
    /// automatically.
    static func openableUrl(_ payload: String) -> URL? {
        guard let url = URL(string: payload.trimmingCharacters(in: .whitespacesAndNewlines)),
              let scheme = url.scheme?.lowercased(), ["http", "https", "mailto"].contains(scheme) else { return nil }
        return url
    }

    /// Recognised lines, top to bottom, joined for the clipboard.
    static func joinLines(_ lines: [String]) -> String {
        lines.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }.joined(separator: "\n")
    }

    /// A drag in any direction becomes a positive rectangle; a click without movement selects nothing.
    static func selection(from start: CGPoint, to end: CGPoint, minimumSize: CGFloat = 4) -> CGRect? {
        let rect = CGRect(x: min(start.x, end.x), y: min(start.y, end.y), width: abs(end.x - start.x), height: abs(end.y - start.y))
        return rect.width >= minimumSize && rect.height >= minimumSize ? rect : nil
    }
}
