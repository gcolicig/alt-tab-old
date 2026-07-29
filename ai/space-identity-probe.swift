#!/usr/bin/env swift

// Spike tool for S-08: is the managed-space UUID on Tahoe stable and unique enough to key Space aliases?
// It captures labelled snapshots of CGSCopyManagedDisplaySpaces and diffs two of them by UUID.
// Run it from a Terminal inside the GUI session; a headless process has no WindowServer connection.

import Foundation

// MARK: - Private API binding

private let skyLightPath = "/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight"

private typealias MainConnectionFunction = @convention(c) () -> Int32
private typealias CopyManagedDisplaySpacesFunction = @convention(c) (Int32) -> Unmanaged<CFArray>?

private enum SkyLight {
    private static let handle = dlopen(skyLightPath, RTLD_LAZY)

    static func resolve<T>(_ name: String) -> T? {
        guard let handle = handle, let symbol = dlsym(handle, name) else { return nil }
        return unsafeBitCast(symbol, to: T.self)
    }

    static func managedDisplaySpaces() -> [NSDictionary]? {
        guard let mainConnection: MainConnectionFunction = resolve("CGSMainConnectionID") else { return nil }
        guard let copySpaces: CopyManagedDisplaySpacesFunction = resolve("CGSCopyManagedDisplaySpaces") else { return nil }
        guard let displays = copySpaces(mainConnection())?.takeRetainedValue() as? [NSDictionary] else { return nil }
        return displays
    }
}

// MARK: - Snapshot model

struct SpaceRecord: Codable {
    let globalIndex: Int
    let indexOnDisplay: Int
    let display: String
    let uuid: String
    let id64: String
    let managedSpaceId: String
    let type: Int
    let isCurrent: Bool
    /// Every key the dictionary carried, so an unexpected Tahoe payload is visible instead of silently dropped.
    let availableKeys: [String]
}

struct Snapshot: Codable {
    let label: String
    let capturedAt: String
    let osVersion: String
    let spaces: [SpaceRecord]
}

// MARK: - Capture

private func stringValue(_ space: NSDictionary, _ key: String) -> String {
    guard let value = space[key] else { return "" }
    if let string = value as? String { return string }
    if let number = value as? NSNumber { return number.stringValue }
    return String(describing: value)
}

private func captureSpaces() -> [SpaceRecord]? {
    guard let displays = SkyLight.managedDisplaySpaces() else { return nil }
    var records = [SpaceRecord]()
    displays.forEach { display in
        let identifier = stringValue(display, "Display Identifier")
        // Matched on id64, not uuid: the first Space carries no uuid on Tahoe 26.5.1, so a uuid match
        // would silently mark no Space as current.
        let currentId64 = (display["Current Space"] as? NSDictionary).map { stringValue($0, "id64") } ?? ""
        let spaces = display["Spaces"] as? [NSDictionary] ?? []
        spaces.enumerated().forEach { offset, space in
            let id64 = stringValue(space, "id64")
            records.append(SpaceRecord(
                globalIndex: records.count + 1,
                indexOnDisplay: offset + 1,
                display: identifier,
                uuid: stringValue(space, "uuid"),
                id64: id64,
                managedSpaceId: stringValue(space, "ManagedSpaceID"),
                type: (space["type"] as? NSNumber)?.intValue ?? -1,
                isCurrent: !id64.isEmpty && id64 == currentId64,
                availableKeys: (space.allKeys.compactMap { $0 as? String }).sorted()))
        }
    }
    return records
}

// MARK: - Storage

private let snapshotDirectory = FileManager.default
    .homeDirectoryForCurrentUser
    .appendingPathComponent("Library/Application Support/AltTabPlusSpaceIdentity", isDirectory: true)

private func snapshotUrl(_ label: String) -> URL {
    snapshotDirectory.appendingPathComponent("\(label).json")
}

private func writeSnapshot(_ snapshot: Snapshot) throws {
    try FileManager.default.createDirectory(at: snapshotDirectory, withIntermediateDirectories: true)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    try encoder.encode(snapshot).write(to: snapshotUrl(snapshot.label), options: .atomic)
}

private func readSnapshot(_ label: String) throws -> Snapshot {
    let data = try Data(contentsOf: snapshotUrl(label))
    return try JSONDecoder().decode(Snapshot.self, from: data)
}

// MARK: - Reporting

private func printTable(_ spaces: [SpaceRecord]) {
    print("  #  display                               idx  type  cur  uuid                                  id64")
    spaces.forEach {
        let display = $0.display.padding(toLength: 36, withPad: " ", startingAt: 0)
        let uuid = ($0.uuid.isEmpty ? "<missing>" : $0.uuid).padding(toLength: 37, withPad: " ", startingAt: 0)
        let index = String($0.indexOnDisplay).padding(toLength: 4, withPad: " ", startingAt: 0)
        let type = String($0.type).padding(toLength: 5, withPad: " ", startingAt: 0)
        print(String(format: "%3d  ", $0.globalIndex) + display + " " + index + " " + type + " " + ($0.isCurrent ? " *   " : "     ") + uuid + " " + $0.id64)
    }
}

private func reportUniqueness(_ snapshot: Snapshot) {
    let uuids = snapshot.spaces.map { $0.uuid }
    let missing = snapshot.spaces.filter { $0.uuid.isEmpty }
    let duplicates = Dictionary(grouping: uuids.filter { !$0.isEmpty }, by: { $0 }).filter { $0.value.count > 1 }
    print("\nUniqueness within this snapshot:")
    print("  spaces: \(snapshot.spaces.count), spaces without a uuid: \(missing.count), duplicated uuids: \(duplicates.count)")
    duplicates.keys.sorted().forEach { print("  DUPLICATE \($0)") }
    missing.forEach { print("  NO UUID at index \($0.indexOnDisplay) on \($0.display), id64 \($0.id64) — cannot be aliased by uuid") }
    let keySets = Set(snapshot.spaces.map { $0.availableKeys.joined(separator: ",") })
    if keySets.count > 1 {
        print("  note: spaces carry differing key sets; inspect the json")
    }
    if let keys = snapshot.spaces.first?.availableKeys {
        print("  keys per space: \(keys.joined(separator: ", "))")
    }
}

private func reportDiff(_ before: Snapshot, _ after: Snapshot) {
    let beforeByUuid = Dictionary(grouping: before.spaces.filter { !$0.uuid.isEmpty }, by: { $0.uuid })
    let afterByUuid = Dictionary(grouping: after.spaces.filter { !$0.uuid.isEmpty }, by: { $0.uuid })
    let survived = Set(beforeByUuid.keys).intersection(afterByUuid.keys).sorted()
    let vanished = Set(beforeByUuid.keys).subtracting(afterByUuid.keys).sorted()
    let appeared = Set(afterByUuid.keys).subtracting(beforeByUuid.keys).sorted()
    print("Diff \(before.label) -> \(after.label)")
    print("  \(before.capturedAt) -> \(after.capturedAt)")
    print("  spaces: \(before.spaces.count) -> \(after.spaces.count)")
    let missingBefore = before.spaces.filter { $0.uuid.isEmpty }.count
    let missingAfter = after.spaces.filter { $0.uuid.isEmpty }.count
    if missingBefore > 0 || missingAfter > 0 {
        print("  excluded from this diff: \(missingBefore) -> \(missingAfter) spaces without a uuid")
    }
    print("\nSurvived (\(survived.count)):")
    survived.forEach { uuid in
        guard let old = beforeByUuid[uuid]?.first, let new = afterByUuid[uuid]?.first else { return }
        var changes = [String]()
        if old.indexOnDisplay != new.indexOnDisplay { changes.append("index \(old.indexOnDisplay)->\(new.indexOnDisplay)") }
        if old.display != new.display { changes.append("display \(old.display)->\(new.display)") }
        if old.id64 != new.id64 { changes.append("id64 \(old.id64)->\(new.id64)") }
        if old.managedSpaceId != new.managedSpaceId { changes.append("managedSpaceId \(old.managedSpaceId)->\(new.managedSpaceId)") }
        if old.type != new.type { changes.append("type \(old.type)->\(new.type)") }
        print("  \(uuid)  \(changes.isEmpty ? "identical" : changes.joined(separator: ", "))")
    }
    print("\nVanished (\(vanished.count)):")
    vanished.forEach { print("  \($0)  was index \(beforeByUuid[$0]?.first?.indexOnDisplay ?? -1) on \(beforeByUuid[$0]?.first?.display ?? "?")") }
    print("\nAppeared (\(appeared.count)):")
    appeared.forEach { print("  \($0)  now index \(afterByUuid[$0]?.first?.indexOnDisplay ?? -1) on \(afterByUuid[$0]?.first?.display ?? "?")") }
    printVerdict(survived.count, vanished.count, appeared.count, before, after)
}

private func printVerdict(_ survived: Int, _ vanished: Int, _ appeared: Int, _ before: Snapshot, _ after: Snapshot) {
    print("\nVerdict input for S-08:")
    if before.spaces.count == after.spaces.count, vanished == 0, appeared == 0 {
        print("  every uuid survived and no uuid was replaced")
    } else {
        print("  uuid set changed: \(vanished) vanished, \(appeared) appeared — expected only for create/delete steps")
    }
    let idsChanged = Set(before.spaces.map { $0.id64 }) != Set(after.spaces.map { $0.id64 })
    print("  id64 set \(idsChanged ? "changed" : "unchanged") — a changed id64 with a stable uuid is exactly why aliases must not key on id64")
}

// MARK: - Commands

private func capture(_ label: String) throws {
    guard let spaces = captureSpaces() else {
        print("error: could not read managed display spaces; is this running inside the GUI session?")
        exit(1)
    }
    let formatter = ISO8601DateFormatter()
    let snapshot = Snapshot(label: label, capturedAt: formatter.string(from: Date()), osVersion: ProcessInfo.processInfo.operatingSystemVersionString, spaces: spaces)
    try writeSnapshot(snapshot)
    print("Captured '\(label)' (\(snapshot.osVersion))")
    printTable(spaces)
    reportUniqueness(snapshot)
    print("\nSaved to \(snapshotUrl(label).path)")
}

private func show(_ label: String) throws {
    let snapshot = try readSnapshot(label)
    print("Snapshot '\(snapshot.label)' captured \(snapshot.capturedAt) on \(snapshot.osVersion)")
    printTable(snapshot.spaces)
    reportUniqueness(snapshot)
}

private func list() throws {
    let files = (try? FileManager.default.contentsOfDirectory(at: snapshotDirectory, includingPropertiesForKeys: nil)) ?? []
    let labels = files.filter { $0.pathExtension == "json" }.map { $0.deletingPathExtension().lastPathComponent }.sorted()
    guard !labels.isEmpty else {
        print("No snapshots in \(snapshotDirectory.path)")
        return
    }
    print("Snapshots in \(snapshotDirectory.path):")
    try labels.forEach { print("  \($0)  (\(try readSnapshot($0).spaces.count) spaces, \(try readSnapshot($0).capturedAt))") }
}

private func usage() {
    print("""
    S-08 managed-space identity probe

      swift ai/space-identity-probe.swift capture <label>   capture and save a labelled snapshot
      swift ai/space-identity-probe.swift show <label>      reprint a saved snapshot
      swift ai/space-identity-probe.swift list              list saved snapshots
      swift ai/space-identity-probe.swift diff <a> <b>      compare two snapshots by uuid

    Snapshots live in ~/Library/Application Support/AltTabPlusSpaceIdentity and survive a reboot.
    Follow docs/space-identity-checklist.md for the step order.
    """)
}

let arguments = Array(CommandLine.arguments.dropFirst())
do {
    switch (arguments.first, arguments.count) {
        case ("capture", 2): try capture(arguments[1])
        case ("show", 2): try show(arguments[1])
        case ("list", 1): try list()
        case ("diff", 3): reportDiff(try readSnapshot(arguments[1]), try readSnapshot(arguments[2]))
        default: usage()
    }
} catch {
    print("error: \(error)")
    exit(1)
}
