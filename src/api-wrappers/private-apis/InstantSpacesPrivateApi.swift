import Cocoa
import Darwin

enum InstantSpacesPrivateApi {
    private typealias MainConnectionFunction = @convention(c) () -> CGSConnectionID
    private typealias CurrentSpaceFunction = @convention(c) (CGSConnectionID, CFString) -> CGSSpaceID
    private typealias SpaceTypeFunction = @convention(c) (CGSConnectionID, CGSSpaceID) -> Int32
    private static let handle = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY)
    private static let mainConnection: MainConnectionFunction? = resolve("CGSMainConnectionID")
    private static let currentSpace: CurrentSpaceFunction? = resolve("CGSManagedDisplayGetCurrentSpace")

    // CGSManagedDisplaySetCurrentSpace is deliberately not bound: switching that way desynchronized the
    // Dock and the WindowServer on Tahoe, which composited the target Space's windows onto the visible
    // one and broke native Mission Control switching until the Dock was restarted.

    static var isAvailable: Bool {
        handle != nil && mainConnection != nil && currentSpace != nil
    }

    /// Temporary diagnostic for the S-06 spike: 0 is a user desktop, 4 a fullscreen Space.
    static func spaceType(_ spaceId: CGSSpaceID) -> Int? {
        guard let mainConnection, let spaceType: SpaceTypeFunction = resolve("CGSSpaceGetType") else { return nil }
        let connection = mainConnection()
        guard connection != 0 else { return nil }
        return Int(spaceType(connection, spaceId))
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
