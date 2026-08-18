import Cocoa

typealias CGWindow = [CFString: Any]

extension CGWindow {
    static let normalLevel = CGWindowLevelForKey(.normalWindow)
    static let floatingWindow = CGWindowLevelForKey(.floatingWindow)

    static func windows(_ option: CGWindowListOption) -> [CGWindow] {
        return CGWindowListCopyWindowInfo([.excludeDesktopElements, option], kCGNullWindowID) as! [CGWindow]
    }

    /// window-server description of the given windows; a window the window server dropped has no entry
    /// returns nil when the call itself failed, which is not the same as "none of these windows exists"
    /// this is a synchronous window-server call; keep the list short, and prefer calling it off the main thread
    static func descriptions(_ wids: [CGWindowID]) -> [CGWindow]? {
        let rawIds: CFArray = wids.map { UnsafeRawPointer(bitPattern: UInt($0)) }.withUnsafeBufferPointer {
            CFArrayCreate(nil, UnsafeMutablePointer(mutating: $0.baseAddress), $0.count, nil)
        }
        return CGWindowListCreateDescriptionFromArray(rawIds) as? [CGWindow]
    }

    /// `kCGWindowIsOnscreen` for one window; false when the window server reports nothing for it
    /// the key is absent for minimized windows, for windows on other Spaces, and for ordered-out windows
    static func isOnScreen(_ wid: CGWindowID) -> Bool {
        return descriptions([wid])?.first?.isOnScreen() ?? false
    }

    // periphery:ignore
    // workaround: filtering this criteria seems to remove non-windows UI elements
    func isNotMenubarOrOthers() -> Bool {
        return layer() == 0
    }

    // periphery:ignore
    func id() -> CGWindowID? {
        return value(kCGWindowNumber, CGWindowID.self)
    }

    func layer() -> Int? {
        return value(kCGWindowLayer, Int.self)
    }

    // periphery:ignore
    func bounds() -> NSRect? {
        if let cfDictionary = value(kCGWindowBounds, CFDictionary.self) {
            return NSRect(dictionaryRepresentation: cfDictionary)
        }
        return nil
    }

    // periphery:ignore
    func ownerPID() -> pid_t? {
        return value(kCGWindowOwnerPID, pid_t.self)
    }

    func ownerName() -> String? {
        return value(kCGWindowOwnerName, String.self)
    }

    func title() -> String? {
        return value(kCGWindowName, String.self)
    }

    func isOnScreen() -> Bool {
        return value(kCGWindowIsOnscreen, Bool.self) ?? false
    }

    private func value<T>(_ key: CFString, _ type: T.Type) -> T? {
        return self[key] as? T
    }
}
