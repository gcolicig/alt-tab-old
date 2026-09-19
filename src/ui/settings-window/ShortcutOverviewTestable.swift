import Foundation

/// Story 16, stage 3: the shortcut overview as data, independent of AppKit and of the live shortcut table.
enum ShortcutStatus: Equatable {
    case unassigned
    case ok
    /// AltTab+ disables the matching macOS shortcut while it is assigned and gives it back afterwards.
    case replacesMacosShortcut
    case duplicate(otherTitle: String)
    case reservedByMacos
    case usedByGameOverlay

    var isConflict: Bool {
        switch self {
            case .duplicate, .reservedByMacos, .usedByGameOverlay: return true
            default: return false
        }
    }
}

enum ShortcutOverviewFilter: Int, CaseIterable {
    case all
    case assigned
    case conflicts
}

struct ShortcutOverviewRow: Equatable {
    let key: String
    let title: String
    let groupOrder: Int
    let groupTitle: String
    /// The settings section that owns the recorder; nil when the overview itself shows the recorder.
    let ownerSectionId: String?
    let status: ShortcutStatus
}

enum ShortcutOverview {
    static func visible(_ rows: [ShortcutOverviewRow], _ filter: ShortcutOverviewFilter) -> [ShortcutOverviewRow] {
        switch filter {
            case .all: return rows
            case .assigned: return rows.filter { $0.status != .unassigned }
            case .conflicts: return rows.filter { $0.status.isConflict }
        }
    }

    static func conflicts(_ rows: [ShortcutOverviewRow]) -> [ShortcutOverviewRow] {
        rows.filter { $0.status.isConflict }.sorted(by: inGroupOrder)
    }

    /// Groups in their fixed order, rows by title inside a group; conflicts are listed separately on top.
    static func grouped(_ rows: [ShortcutOverviewRow]) -> [(String, [ShortcutOverviewRow])] {
        let sorted = rows.sorted(by: inGroupOrder)
        var groups = [(String, [ShortcutOverviewRow])]()
        sorted.forEach { row in
            if groups.last?.0 == row.groupTitle {
                groups[groups.count - 1].1.append(row)
            } else {
                groups.append((row.groupTitle, [row]))
            }
        }
        return groups
    }

    private static func inGroupOrder(_ lhs: ShortcutOverviewRow, _ rhs: ShortcutOverviewRow) -> Bool {
        if lhs.groupOrder != rhs.groupOrder { return lhs.groupOrder < rhs.groupOrder }
        return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
    }

    /// Switcher triggers stay with the switcher, and are not action shortcuts.
    static func isActionShortcutKey(_ key: String) -> Bool {
        !key.hasPrefix("holdShortcut") && !key.hasPrefix("nextWindowShortcut")
    }
}
