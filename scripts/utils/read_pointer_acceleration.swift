#!/usr/bin/env swift
// Independent read of the effective pointer acceleration, for docs/pointer-ownership-checklist.md.
//
// The checklist must not measure through the app under test: the module once reported success by reading
// back a preference it had just written, which always succeeds. This script asks the HID system directly,
// in its own process, the same way the system applies the value.
//
// `defaults read -g com.apple.mouse.scaling` is NOT a substitute. The preference and the effective value
// can diverge, and on a machine where System Settings never wrote the pair, the preference does not exist
// at all while the HID system still reports a value.
//
// Run with: swift scripts/utils/read_pointer_acceleration.swift
import Foundation
import IOKit

typealias OpenEventStatusFunction = @convention(c) () -> io_connect_t
typealias CloseEventStatusFunction = @convention(c) (io_connect_t) -> Void
typealias GetAccelerationFunction = @convention(c) (io_connect_t, CFString, UnsafeMutablePointer<Double>) -> IOReturn

func resolve<T>(_ name: String, _: T.Type) -> T? {
    // RTLD_DEFAULT: the symbols are deprecated since 10.12, so they are resolved at run time and their
    // absence is reported instead of failing to launch — same rule the app itself follows (V-03)
    guard let symbol = dlsym(UnsafeMutableRawPointer(bitPattern: -2), name) else { return nil }
    return unsafeBitCast(symbol, to: T.self)
}

guard let openEventStatus = resolve("NXOpenEventStatus", OpenEventStatusFunction.self),
      let closeEventStatus = resolve("NXCloseEventStatus", CloseEventStatusFunction.self),
      let getAcceleration = resolve("IOHIDGetAccelerationWithKey", GetAccelerationFunction.self) else {
    print("The IOKit hidsystem symbols did not resolve; on this macOS the checklist cannot be run this way")
    exit(1)
}
let connection = openEventStatus()
guard connection != 0 else {
    print("NXOpenEventStatus returned no connection to the event status driver")
    exit(1)
}
defer { closeEventStatus(connection) }
for key in ["HIDMouseAcceleration", "HIDTrackpadAcceleration"] {
    var value = Double(0)
    if getAcceleration(connection, key as CFString, &value) == KERN_SUCCESS {
        print("\(key): \(value)")
    } else {
        print("\(key): unreadable")
    }
}
