import Cocoa
import Darwin

enum InstantSpacesPrivateApi {
    private typealias MainConnectionFunction = @convention(c) () -> CGSConnectionID
    private typealias CurrentSpaceFunction = @convention(c) (CGSConnectionID, CFString) -> CGSSpaceID
    private typealias ShowHideSpacesFunction = @convention(c) (CGSConnectionID, CFArray) -> Void
    private typealias SetCurrentSpaceFunction = @convention(c) (CGSConnectionID, CFString, CGSSpaceID) -> CGError
    private static let handle = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY)
    private static let mainConnection: MainConnectionFunction? = resolve("CGSMainConnectionID")
    private static let currentSpace: CurrentSpaceFunction? = resolve("CGSManagedDisplayGetCurrentSpace")
    private static let showSpaces: ShowHideSpacesFunction? = resolve("CGSShowSpaces")
    private static let hideSpaces: ShowHideSpacesFunction? = resolve("CGSHideSpaces")
    private static let setCurrentSpace: SetCurrentSpaceFunction? = resolve("CGSManagedDisplaySetCurrentSpace")

    static var isAvailable: Bool {
        handle != nil && mainConnection != nil && currentSpace != nil
    }

    /// Whether a display other than the one the gesture would reach can be switched.
    static var canSwitchAnyDisplay: Bool {
        isAvailable && showSpaces != nil && hideSpaces != nil && setCurrentSpace != nil
    }

    static func currentSpaceId(_ displayId: CFString) -> CGSSpaceID? {
        guard let mainConnection, let currentSpace else { return nil }
        let connection = mainConnection()
        guard connection != 0 else { return nil }
        let spaceId = currentSpace(connection, displayId)
        return spaceId == 0 ? nil : spaceId
    }

    /// Switches a display by moving the Space layers, which needs neither the cursor nor the active
    /// menubar display and therefore reaches any display.
    ///
    /// `CGSManagedDisplaySetCurrentSpace` was long excluded here because it left the target Space's
    /// windows composited over the visible one and broke native Mission Control until the Dock was
    /// restarted. Measured again on 2026-08-06: that is what the call does *on its own*, since it moves
    /// only the pointer to the current Space while the layers stay where they were. Shown and hidden
    /// first, it behaves — six runs switched the target display alone, and native switching, Mission
    /// Control and window placement were all intact afterwards.
    static func switchSpace(on displayId: CFString, from currentSpaceId: CGSSpaceID, to targetSpaceId: CGSSpaceID) -> Bool {
        guard let mainConnection, let showSpaces, let hideSpaces, let setCurrentSpace else { return false }
        let connection = mainConnection()
        guard connection != 0, currentSpaceId != targetSpaceId else { return false }
        showSpaces(connection, [targetSpaceId] as CFArray)
        hideSpaces(connection, [currentSpaceId] as CFArray)
        return setCurrentSpace(connection, displayId, targetSpaceId) == .success
    }

    private static func resolve<T>(_ name: String) -> T? {
        guard let handle, let symbol = dlsym(handle, name) else { return nil }
        return unsafeBitCast(symbol, to: T.self)
    }
}
