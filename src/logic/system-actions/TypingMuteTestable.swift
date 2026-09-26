import Foundation

/// spec-typing-mute.md. The pure decisions behind muting the microphone while typing. No CoreAudio, no tap:
/// the runtime in `TypingMute` feeds events in and carries the decisions out.
enum TypingMuteKey: Equatable {
    case down(isAutorepeat: Bool)
    case up
    case modifiers
}

enum TypingMuteKeyDecision: Equatable {
    case none
    case mute(generation: UInt64)
}

enum TypingMuteTimerDecision: Equatable {
    case stop
    case wait(until: TimeInterval)
    case release
}

struct TypingMuteStateMachine {
    private(set) var isHolding = false
    private(set) var deadline: TimeInterval = 0
    private(set) var generation: UInt64 = 0
    var isArmed = false

    /// Only a fresh key press starts a phase: a held key does not click, and a modifier alone is too quiet.
    /// Every key event inside a phase moves the deadline, because releasing a key clicks as well.
    mutating func key(_ key: TypingMuteKey, at now: TimeInterval, hold: TimeInterval) -> TypingMuteKeyDecision {
        if isHolding {
            deadline = max(deadline, now + hold)
            return .none
        }
        guard isArmed, key == .down(isAutorepeat: false) else { return .none }
        isHolding = true
        generation &+= 1
        deadline = now + hold
        return .mute(generation: generation)
    }

    mutating func timerFired(at now: TimeInterval) -> TypingMuteTimerDecision {
        guard isHolding else { return .stop }
        guard now >= deadline else { return .wait(until: deadline) }
        isHolding = false
        return .release
    }

    /// Ends a phase from outside the timer: a manual mute, the panic switch, quitting, turning it off.
    /// The generation moves so a mute that is still queued for the ended phase is dropped.
    @discardableResult
    mutating func end() -> Bool {
        let wasHolding = isHolding
        isHolding = false
        generation &+= 1
        return wasHolding
    }

    func isCurrent(_ generation: UInt64) -> Bool {
        isHolding && generation == self.generation
    }
}

/// How a device is silenced. Volume first: Teams shows "your microphone is muted" for the mute property.
enum TypingMuteRoute: String, Codable {
    case volume
    case mute
}

struct TypingMuteTarget: Equatable {
    let device: UInt32
    let uid: String
    let route: TypingMuteRoute
    let currentValue: Float32
}

/// One device silenced by typing. `written` is what TypingMute wrote, so a different value read later
/// belongs to somebody else. It is also the crash marker entry.
struct TypingMuteOwnedDevice: Equatable, Codable {
    let device: UInt32
    let uid: String
    let route: TypingMuteRoute
    let original: Float32
    let written: Float32
}

enum TypingMuteOwnership {
    private static let tolerance: Float32 = 0.001

    /// A device the user already silenced is not taken: it would be given back unmuted.
    static func canSilence(_ target: TypingMuteTarget) -> Bool {
        target.route == .volume ? target.currentValue > tolerance : target.currentValue < 0.5
    }

    static func own(_ target: TypingMuteTarget) -> TypingMuteOwnedDevice {
        TypingMuteOwnedDevice(device: target.device, uid: target.uid, route: target.route,
            original: target.currentValue, written: target.route == .volume ? 0 : 1)
    }

    static func isExternalChange(_ owned: TypingMuteOwnedDevice, observed: Float32) -> Bool {
        abs(observed - owned.written) > tolerance
    }

    /// The value to write back, or nil when somebody else changed the device in the meantime.
    static func restoreValue(_ owned: TypingMuteOwnedDevice, observed: Float32) -> Float32? {
        isExternalChange(owned, observed: observed) ? nil : owned.original
    }

    static func encodeMarker(_ devices: [TypingMuteOwnedDevice]) -> String {
        guard let data = try? JSONEncoder().encode(devices) else { return "" }
        return String(data: data, encoding: .utf8) ?? ""
    }

    static func decodeMarker(_ marker: String) -> [TypingMuteOwnedDevice] {
        guard let data = marker.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([TypingMuteOwnedDevice].self, from: data)) ?? []
    }
}

/// Milliseconds from the tap seeing the key to the write returning, the last `capacity` per device.
struct TypingMuteLatencies {
    static let capacity = 200
    private var samples = [String: [Double]]()

    mutating func record(_ uid: String, _ milliseconds: Double) {
        var values = samples[uid] ?? []
        if values.count == Self.capacity { values.removeFirst() }
        values.append(milliseconds)
        samples[uid] = values
    }

    func summary() -> String {
        guard !samples.isEmpty else { return "no samples" }
        return samples.keys.sorted().map { uid in
            let sorted = samples[uid]!.sorted()
            return String(format: "%@ p50 %.1f ms p95 %.1f ms (n=%d)", uid, percentile(sorted, 0.5), percentile(sorted, 0.95), sorted.count)
        }.joined(separator: ", ")
    }

    private func percentile(_ sorted: [Double], _ fraction: Double) -> Double {
        sorted[min(sorted.count - 1, Int(Double(sorted.count - 1) * fraction + 0.5))]
    }
}
