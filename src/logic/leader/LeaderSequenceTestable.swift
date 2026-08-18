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

/// One user-configured Leader binding: the keys pressed after the trigger, and the action they run.
/// This is the flat shape the settings store; `LeaderTrie.build` folds a list of them into the trie the
/// session walks. Keeping storage flat makes the settings editor and the persisted JSON simple, and moves
/// every ambiguity check into one place.
struct LeaderBinding: Equatable {
    let keys: [LeaderKey]
    let action: ActionIdentifier
}

/// Why a set of bindings cannot form a deterministic trie. Both cases would make the same keystrokes mean
/// two things, which is exactly what the trie's "a node runs an action or leads on, never both" rule forbids.
enum LeaderBuildError: Equatable, Error {
    /// two bindings share the same key path
    case duplicatePath([LeaderKey])
    /// one binding's path is a strict prefix of another's, so the shorter one could never be reached
    case prefixConflict(shorter: [LeaderKey], longer: [LeaderKey])
    /// a binding has no keys at all; the trigger itself cannot also be a binding
    case emptyPath
}

struct LeaderTrie: Equatable {
    let root: [LeaderKey: LeaderNode]

    init(_ root: [LeaderKey: LeaderNode] = [:]) {
        self.root = root
    }

    /// Folds flat bindings into the nested trie, refusing any set that would be ambiguous. Insertion order
    /// does not change the outcome: a conflict is reported whichever binding is seen first.
    static func build(from bindings: [LeaderBinding]) -> Result<LeaderTrie, LeaderBuildError> {
        var root = [LeaderKey: LeaderNode]()
        for binding in bindings {
            guard !binding.keys.isEmpty else { return .failure(.emptyPath) }
            if let error = insert(binding.keys[...], binding.action, into: &root, pathSoFar: []) {
                return .failure(error)
            }
        }
        return .success(LeaderTrie(root))
    }

    private static func insert(_ keys: ArraySlice<LeaderKey>, _ action: ActionIdentifier,
                               into level: inout [LeaderKey: LeaderNode], pathSoFar: [LeaderKey]) -> LeaderBuildError? {
        guard let key = keys.first else { return nil }
        let path = pathSoFar + [key]
        let rest = keys.dropFirst()
        if rest.isEmpty {
            // this key is the leaf; anything already sitting here is a conflict
            switch level[key] {
                case .none: level[key] = .action(action); return nil
                case .action: return .duplicatePath(path)
                case .group(let children): return .prefixConflict(shorter: path, longer: path + [Array(children.keys)[0]])
            }
        }
        switch level[key] {
            case .none:
                var child = [LeaderKey: LeaderNode]()
                let error = insert(rest, action, into: &child, pathSoFar: path)
                level[key] = .group(child)
                return error
            case .action:
                // the shorter binding already claimed this key as a leaf; the longer one cannot pass through it
                return .prefixConflict(shorter: path, longer: pathSoFar + Array(keys))
            case .group(var children):
                let error = insert(rest, action, into: &children, pathSoFar: path)
                level[key] = .group(children)
                return error
        }
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
