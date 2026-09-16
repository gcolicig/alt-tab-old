import Foundation

/// Persists the fixed profile slots as plain per-field preferences, so the settings editor can reuse the
/// standard text and recorder controls. Each slot's shortcut is a normal global action shortcut (like the
/// app/URL slots). `ProfileController` reads assembled `Profile` values from here.
enum ProfileStore {
    static func shortcutPreferenceKey(_ index: Int) -> String { "profileShortcut\(index)" }
    static func nameKey(_ index: Int) -> String { "profileName\(index)" }
    static func appsKey(_ index: Int) -> String { "profileApps\(index)" }
    static func layoutKey(_ index: Int) -> String { "profileLayout\(index)" }
    static func spaceUuidKey(_ index: Int) -> String { "profileSpaceUuid\(index)" }

    static func profile(_ index: Int) -> Profile? {
        let layout = CachedUserDefaults.string(layoutKey(index))
        let space = CachedUserDefaults.string(spaceUuidKey(index))
        let profile = Profile(
            name: CachedUserDefaults.string(nameKey(index)),
            appBundleIds: parseBundleIds(CachedUserDefaults.string(appsKey(index))),
            layout: layout.isEmpty ? nil : layout,
            spaceUuid: space.isEmpty ? nil : space)
        return profile.isEmpty ? nil : profile
    }

    /// Bundle identifiers are entered one per line, commas allowed too; blanks are dropped.
    static func parseBundleIds(_ raw: String) -> [String] {
        raw.split(whereSeparator: { $0 == "\n" || $0 == "," })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    static func allProfiles() -> [(index: Int, profile: Profile)] {
        (0..<Preferences.maxProfileCount).compactMap { index in profile(index).map { (index, $0) } }
    }
}
