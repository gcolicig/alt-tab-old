import Foundation

/// Story 16, stage 2: the fixed preference slots shown as a list. The slots stay the storage because
/// Leader and FlickRing bindings, shortcuts and exported settings files refer to slot numbers.
enum SlotList {
    static func isOccupied(_ value: String) -> Bool {
        !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    static func occupied(_ values: [String]) -> [Int] {
        values.indices.filter { isOccupied(values[$0]) }
    }

    static func firstFree(_ values: [String]) -> Int? {
        values.indices.first { !isOccupied(values[$0]) }
    }

    /// A slot that holds only whitespace looked filled in the old editor; the one-time cleanup empties it.
    static func needsCleanup(_ value: String) -> Bool {
        !value.isEmpty && !isOccupied(value)
    }

    /// Profile apps are stored one bundle id per line. Adding keeps the order and skips duplicates.
    static func addingBundleIds(_ stored: String, _ additions: [String]) -> String {
        var ids = ProfileAppsFormat.parse(stored)
        additions.filter { !ids.contains($0) }.forEach { ids.append($0) }
        return ids.joined(separator: "\n")
    }

    static func removingBundleId(_ stored: String, _ bundleId: String) -> String {
        ProfileAppsFormat.parse(stored).filter { $0 != bundleId }.joined(separator: "\n")
    }
}

/// Same rules as `ProfileStore.parseBundleIds`, which lives in the app target only.
enum ProfileAppsFormat {
    static func parse(_ raw: String) -> [String] {
        raw.split(whereSeparator: { $0 == "\n" || $0 == "," })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
}
