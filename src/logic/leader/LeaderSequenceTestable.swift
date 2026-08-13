import AppKit
import Foundation

/// One step of a Leader sequence: a key, identified the way the event tap sees it.
struct LeaderKey: Hashable, Codable {
    let keyCode: UInt32
    /// Only modifiers that distinguish a binding are kept; Caps Lock and the numeric pad flag are noise.
    let modifiers: UInt

    static let relevantModifiers: NSEvent.ModifierFlags = [.command, .shift, .control, .option, .function]

    init(keyCode: UInt32, modifiers: NSEvent.ModifierFlags = []) {
        self.keyCode = keyCode
        self.modifiers = modifiers.intersection(LeaderKey.relevantModifiers).rawValue
    }
}

/// Nested, deterministic sequences. A node either runs an action or leads to further keys, never both:
/// a prefix that is also a binding would make the sequence ambiguous, and the user could not tell whether
/// pressing more keys was still possible.
indirect enum LeaderNode: Equatable {
    case action(ActionIdentifier)
    case group([LeaderKey: LeaderNode])
}

enum LeaderLookup: Equatable {
    case run(ActionIdentifier)
    case awaitMore([LeaderKey])
    case noMatch
}

struct LeaderTrie: Equatable {
    let root: [LeaderKey: LeaderNode]

    init(_ root: [LeaderKey: LeaderNode] = [:]) {
        self.root = root
    }

    func lookup(_ sequence: [LeaderKey]) -> LeaderLookup {
        var level = root
        for (index, key) in sequence.enumerated() {
            guard let node = level[key] else { return .noMatch }
            switch node {
                case .action(let identifier):
                    // keys beyond a complete binding are not part of it
                    return index == sequence.count - 1 ? .run(identifier) : .noMatch
                case .group(let children):
                    level = children
            }
        }
        // nothing can follow, so there is nothing to await: reporting `awaitMore` with an empty list would
        // have a caller arm a session that can only ever swallow the next key and then abort. That is the
        // outcome this type exists to avoid, and it is reachable with no bindings configured at all.
        guard !level.isEmpty else { return .noMatch }
        return .awaitMore(Array(level.keys))
    }
}

enum LeaderSessionState: Equatable {
    case idle
    case collecting([LeaderKey])
}

enum LeaderOutcome: Equatable {
    case keepCollecting([LeaderKey])
    case run(ActionIdentifier)
    case abort
}

enum LeaderSession {
    /// The sequence is dropped after this long without a key, so a Leader left armed by accident cannot
    /// swallow the next thing typed.
    static let timeout = 2.0
    /// Escape.
    static let abortKeyCode = UInt32(53)

    static func begin() -> LeaderSessionState {
        .collecting([])
    }

    static func accept(_ state: LeaderSessionState, key: LeaderKey, in trie: LeaderTrie) -> LeaderOutcome {
        guard case .collecting(let sequence) = state else { return .abort }
        guard key.keyCode != abortKeyCode else { return .abort }
        let extended = sequence + [key]
        switch trie.lookup(extended) {
            case .run(let identifier): return .run(identifier)
            case .awaitMore: return .keepCollecting(extended)
            // a wrong key ends the sequence rather than being ignored: silently swallowing keystrokes is
            // worse than making the user start over
            case .noMatch: return .abort
        }
    }

    static func hasExpired(lastKeyAt: TimeInterval, now: TimeInterval) -> Bool {
        now - lastKeyAt >= timeout
    }
}
