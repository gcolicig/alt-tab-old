import Cocoa
import Darwin

enum InstantSpacesPrivateApi {
    private typealias MainConnectionFunction = @convention(c) () -> CGSConnectionID
    private typealias CurrentSpaceFunction = @convention(c) (CGSConnectionID, CFString) -> CGSSpaceID
    private static let handle = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY)
    private static let mainConnection: MainConnectionFunction? = resolve("CGSMainConnectionID")
    private static let currentSpace: CurrentSpaceFunction? = resolve("CGSManagedDisplayGetCurrentSpace")

    static var isAvailable: Bool {
        handle != nil && mainConnection != nil && currentSpace != nil
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
