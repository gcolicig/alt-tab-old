import Cocoa
import Darwin

enum InstantSpacesPrivateApi {
    private typealias MainConnectionFunction = @convention(c) () -> CGSConnectionID
    private typealias CurrentSpaceFunction = @convention(c) (CGSConnectionID, CFString) -> CGSSpaceID
    private static let handle = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY)
    private static let mainConnection: MainConnectionFunction? = resolve("CGSMainConnectionID")
    private typealias SetCurrentSpaceFunction = @convention(c) (CGSConnectionID, CFString, CGSSpaceID) -> Void
    private static let currentSpace: CurrentSpaceFunction? = resolve("CGSManagedDisplayGetCurrentSpace")
    private static let setCurrentSpace: SetCurrentSpaceFunction? = resolve("CGSManagedDisplaySetCurrentSpace")

    static var isAvailable: Bool {
        handle != nil && mainConnection != nil && currentSpace != nil
    }

    /// Jumps straight to a Space instead of stepping through the ones in between. Optional: without
    /// this symbol the caller keeps using synthetic swipes.
    static var supportsDirectSwitch: Bool {
        isAvailable && setCurrentSpace != nil
    }

    static func switchDirectly(_ displayId: CFString, to spaceId: CGSSpaceID) -> Bool {
        guard let mainConnection, let setCurrentSpace else { return false }
        let connection = mainConnection()
        guard connection != 0 else { return false }
        setCurrentSpace(connection, displayId, spaceId)
        return true
    }

    static func currentSpaceId(_ displayId: CFString) -> CGSSpaceID? {
        guard let mainConnection, let currentSpace else { return nil }
        let connection = mainConnection()
        guard connection != 0 else { return nil }
        let spaceId = currentSpace(connection, displayId)
        return spaceId == 0 ? nil : spaceId
    }

    private static func resolve<T>(_ name: String) -> T? {
        guard let handle, let symbol = dlsym(handle, name) else { return nil }
        return unsafeBitCast(symbol, to: T.self)
    }
}
