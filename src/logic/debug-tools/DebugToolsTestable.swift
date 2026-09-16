import CoreGraphics
import Foundation

/// Story 13, DB-03: what may leave the machine inside a copied report.
enum DebugRedaction {
    /// Preferences whose values are user content. Matched by prefix because slots are numbered.
    static let redactedKeyPrefixes = ["openUrlValue", "launchAppPath", "launchAppBundleIdentifier", "profileName", "profileApps", "autoQuitBundleIds"]
    static let countOnlyKeys: Set<String> = ["exceptions"]

    static func preferenceValue(key: String, value: String?) -> String {
        guard let value else { return "nil" }
        if countOnlyKeys.contains(key) { return "<\(countEntries(value)) entries>" }
        guard redactedKeyPrefixes.contains(where: { key.hasPrefix($0) }) else { return homeRedacted(value) }
        return value.isEmpty ? "<empty>" : "<set>"
    }

    static func homeRedacted(_ text: String, home: String = NSHomeDirectory()) -> String {
        guard !home.isEmpty, home != "/" else { return text }
        return text.replacingOccurrences(of: home, with: "~")
    }

    private static func countEntries(_ json: String) -> Int {
        guard let data = json.data(using: .utf8), let array = try? JSONSerialization.jsonObject(with: data) as? [Any] else { return 0 }
        return array.count
    }
}

/// One accessibility element as the tree dump sees it, independent of AX so the format is testable.
protocol AccessibilityNode {
    var role: String? { get }
    var subrole: String? { get }
    var roleDescription: String? { get }
    var title: String? { get }
    var identifier: String? { get }
    var frame: CGRect? { get }
    var isEnabled: Bool? { get }
    var isFocused: Bool? { get }
    var settableAttributes: [String] { get }
    var children: [AccessibilityNode] { get }
}

enum AccessibilityTreeFormat {
    static let maxDepth = 8
    static let maxElements = 500
    static let maxTitleLength = 60
    /// Titles of these roles name controls, not content, and stay readable. Everything else, windows
    /// included, is reduced to its length (DB-03 wins over readability).
    static let readableTitleRoles: Set<String> = ["AXButton", "AXMenuItem", "AXMenu", "AXMenuBarItem", "AXMenuButton", "AXCheckBox",
                                                  "AXRadioButton", "AXPopUpButton", "AXTab", "AXTabGroup", "AXToolbar", "AXDisclosureTriangle", "AXSlider"]

    static func render(_ root: AccessibilityNode) -> String {
        var lines = [String]()
        var count = 0
        var truncated = false
        walk(root, depth: 0, &lines, &count, &truncated)
        if truncated { lines.append("… truncated at depth \(maxDepth) or \(maxElements) elements") }
        return lines.joined(separator: "\n")
    }

    private static func walk(_ node: AccessibilityNode, depth: Int, _ lines: inout [String], _ count: inout Int, _ truncated: inout Bool) {
        guard depth < maxDepth, count < maxElements else {
            truncated = true
            return
        }
        count += 1
        lines.append(String(repeating: "  ", count: depth) + line(node))
        node.children.forEach { walk($0, depth: depth + 1, &lines, &count, &truncated) }
    }

    static func line(_ node: AccessibilityNode) -> String {
        var parts = [node.role ?? "?"]
        if let subrole = node.subrole { parts.append("(\(subrole))") }
        if let description = node.roleDescription { parts.append("“\(description)”") }
        if node.role != "AXSecureTextField" {
            appendDetails(node, &parts)
        }
        return parts.joined(separator: " ")
    }

    private static func appendDetails(_ node: AccessibilityNode, _ parts: inout [String]) {
        if let title = node.title, !title.isEmpty { parts.append("title=" + displayTitle(title, role: node.role)) }
        if let identifier = node.identifier, !identifier.isEmpty { parts.append("id=" + identifier) }
        if let frame = node.frame { parts.append("frame=(\(Int(frame.minX)),\(Int(frame.minY)) \(Int(frame.width))x\(Int(frame.height)))") }
        if node.isEnabled == false { parts.append("disabled") }
        if node.isFocused == true { parts.append("focused") }
        if !node.settableAttributes.isEmpty { parts.append("settable=" + node.settableAttributes.joined(separator: ",")) }
    }

    static func displayTitle(_ title: String, role: String?) -> String {
        guard let role, readableTitleRoles.contains(role) else { return "<title \(title.count) chars>" }
        return title.count > maxTitleLength ? String(title.prefix(maxTitleLength)) + "…" : title
    }
}

enum PermissionResetCommand {
    static let tccutil = "/usr/bin/tccutil"
    static let services = ["Accessibility", "ScreenCapture"]

    static func arguments(bundleId: String) -> [[String]] {
        services.map { ["reset", $0, bundleId] }
    }
}
