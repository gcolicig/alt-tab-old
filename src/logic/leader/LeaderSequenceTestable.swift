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

    /// The children reachable right after `sequence`, for the overlay to list what may be pressed next.
    /// Returns nil when the path runs through an action leaf (nothing can follow) or does not exist.
    func level(after sequence: [LeaderKey]) -> [LeaderKey: LeaderNode]? {
        var level = root
        for key in sequence {
            guard case .group(let children)? = level[key] else { return nil }
            level = children
        }
        return level
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

/// Turns the compact settings editor's text into a key path and back. The editor accepts US-ANSI letters and
/// digits, which covers vim-style Leader sequences; modifiers and other keys are out of its scope on purpose,
/// so the editor stays a plain text field instead of a multi-key recorder.
enum LeaderKeyParsing {
    /// character → US-ANSI virtual key code
    static let characterKeyCodes: [Character: UInt32] = [
        "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7, "c": 8, "v": 9,
        "b": 11, "q": 12, "w": 13, "e": 14, "r": 15, "y": 16, "t": 17, "o": 31, "u": 32,
        "i": 34, "p": 35, "l": 37, "j": 38, "k": 40, "n": 45, "m": 46,
        "1": 18, "2": 19, "3": 20, "4": 21, "5": 23, "6": 22, "7": 26, "8": 28, "9": 25, "0": 29,
    ]

    /// nil when a character has no mapping, or the trimmed text is empty. Whitespace separates keys for
    /// readability and is ignored.
    static func parse(_ text: String) -> [LeaderKey]? {
        var keys = [LeaderKey]()
        for character in text.lowercased() where !character.isWhitespace {
            guard let keyCode = characterKeyCodes[character] else { return nil }
            keys.append(LeaderKey(keyCode: keyCode))
        }
        return keys.isEmpty ? nil : keys
    }

    /// The text an all-letters/digits path reads as; a key with modifiers or no mapping shows as "?".
    static func text(for keys: [LeaderKey]) -> String {
        keys.map { key -> String in
            guard key.modifiers == 0, let character = characterKeyCodes.first(where: { $0.value == key.keyCode })?.key else { return "?" }
            return String(character)
        }.joined()
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
