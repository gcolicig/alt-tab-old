import CoreAudio
import Foundation
import IOKit.hidsystem

/// Story 14E. Mute every available input or output through CoreAudio. A microphone without a
/// mute control is muted by its input volume instead; that simulated mute is the only state AltTab+ gives back on quit.
enum AudioMute {
    private static var simulatedInputMutes = [AudioObjectID: Float32]()

    static func isMuted(input: Bool) -> Bool {
        let devices = muteableDevices(input: input)
        return !devices.isEmpty && devices.allSatisfy { isMuted($0, input: input) }
    }

    static func isAvailable(input: Bool) -> Bool {
        !muteableDevices(input: input).isEmpty
    }

    static func toggle(input: Bool) {
        let devices = muteableDevices(input: input)
        guard !devices.isEmpty else { return }
        let muted = isMuted(input: input)
        devices.forEach { device in
            if isSettable(device, kAudioDevicePropertyMute, scope(input)) {
                writeUInt32(device, kAudioDevicePropertyMute, scope(input), muted ? 0 : 1)
            } else if input {
                muted ? restoreSimulatedInputMute(device) : simulateInputMute(device)
            }
        }
        MicMuteIndicator.refresh()
        if input { TeamsMuteSync.microphoneToggled() }
    }

    static func restoreOnQuit() {
        Array(simulatedInputMutes.keys).forEach { restoreSimulatedInputMute($0) }
    }

    private static func simulateInputMute(_ device: AudioObjectID) {
        guard let volume = readFloat(device, kAudioDevicePropertyVolumeScalar, scope(true)) else { return }
        simulatedInputMutes[device] = volume
        writeFloat(device, kAudioDevicePropertyVolumeScalar, scope(true), 0)
    }

    private static func restoreSimulatedInputMute(_ device: AudioObjectID) {
        guard let volume = simulatedInputMutes.removeValue(forKey: device) else { return }
        writeFloat(device, kAudioDevicePropertyVolumeScalar, scope(true), volume)
    }

    /// The microphone key is a privacy control: it affects every currently available input device, not only
    /// the device macOS happens to name as the default while a meeting app may use another one.
    static func inputDevices() -> [AudioObjectID] {
        devices(withChannelsIn: kAudioObjectPropertyScopeInput)
    }

    static func outputDevices() -> [AudioObjectID] {
        devices(withChannelsIn: kAudioObjectPropertyScopeOutput)
    }

    private static func devices(withChannelsIn scope: AudioObjectPropertyScope) -> [AudioObjectID] {
        var address = globalAddress(kAudioHardwarePropertyDevices)
        var size = UInt32(0)
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size) == noErr else { return [] }
        var devices = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &devices) == noErr else { return [] }
        return devices.filter { hasChannels($0, scope: scope) }
    }

    private static func muteableDevices(input: Bool) -> [AudioObjectID] {
        let devices = input ? inputDevices() : outputDevices()
        return devices.filter { isSettable($0, kAudioDevicePropertyMute, scope(input)) || (input && isSettable($0, kAudioDevicePropertyVolumeScalar, scope(input))) }
    }

    private static func isMuted(_ device: AudioObjectID, input: Bool) -> Bool {
        if input, simulatedInputMutes[device] != nil { return true }
        return readUInt32(device, kAudioDevicePropertyMute, scope(input)) == 1
    }

    private static func hasChannels(_ device: AudioObjectID, scope: AudioObjectPropertyScope) -> Bool {
        var address = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyStreamConfiguration, mScope: scope, mElement: kAudioObjectPropertyElementMain)
        guard AudioObjectHasProperty(device, &address) else { return false }
        var size = UInt32(0)
        guard AudioObjectGetPropertyDataSize(device, &address, 0, nil, &size) == noErr else { return false }
        let bufferList = UnsafeMutableRawPointer.allocate(byteCount: Int(size), alignment: MemoryLayout<AudioBufferList>.alignment)
        defer { bufferList.deallocate() }
        guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, bufferList) == noErr else { return false }
        let buffers = UnsafeMutableAudioBufferListPointer(bufferList.assumingMemoryBound(to: AudioBufferList.self))
        return buffers.contains { $0.mNumberChannels > 0 }
    }

    private static func scope(_ input: Bool) -> AudioObjectPropertyScope {
        input ? kAudioObjectPropertyScopeInput : kAudioObjectPropertyScopeOutput
    }

    private static func globalAddress(_ selector: AudioObjectPropertySelector) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
    }

    private static func isSettable(_ device: AudioObjectID, _ selector: AudioObjectPropertySelector, _ scope: AudioObjectPropertyScope) -> Bool {
        var address = AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
        guard AudioObjectHasProperty(device, &address) else { return false }
        var settable = DarwinBoolean(false)
        return AudioObjectIsPropertySettable(device, &address, &settable) == noErr && settable.boolValue
    }

    private static func readUInt32(_ device: AudioObjectID, _ selector: AudioObjectPropertySelector, _ scope: AudioObjectPropertyScope) -> UInt32? {
        var address = AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
        guard AudioObjectHasProperty(device, &address) else { return nil }
        var value = UInt32(0)
        var size = UInt32(MemoryLayout<UInt32>.size)
        return AudioObjectGetPropertyData(device, &address, 0, nil, &size, &value) == noErr ? value : nil
    }

    private static func readFloat(_ device: AudioObjectID, _ selector: AudioObjectPropertySelector, _ scope: AudioObjectPropertyScope) -> Float32? {
        var address = AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
        guard AudioObjectHasProperty(device, &address) else { return nil }
        var value = Float32(0)
        var size = UInt32(MemoryLayout<Float32>.size)
        return AudioObjectGetPropertyData(device, &address, 0, nil, &size, &value) == noErr ? value : nil
    }

    private static func writeUInt32(_ device: AudioObjectID, _ selector: AudioObjectPropertySelector, _ scope: AudioObjectPropertyScope, _ value: UInt32) {
        var address = AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
        var value = value
        report(AudioObjectSetPropertyData(device, &address, 0, nil, UInt32(MemoryLayout<UInt32>.size), &value), selector)
    }

    private static func writeFloat(_ device: AudioObjectID, _ selector: AudioObjectPropertySelector, _ scope: AudioObjectPropertyScope, _ value: Float32) {
        var address = AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
        var value = value
        report(AudioObjectSetPropertyData(device, &address, 0, nil, UInt32(MemoryLayout<Float32>.size), &value), selector)
    }

    private static func report(_ status: OSStatus, _ selector: AudioObjectPropertySelector) {
        guard status != noErr else { return }
        Logger.warning { "CoreAudio write \(selector) failed: \(status)" }
    }
}

/// The microphone key toggles the microphone mute when the setting is on. The remap lives in the HID
/// system until logout, so it is released on quit and whenever the setting is turned off.
enum MicKey {
    private static let property = "UserKeyMapping" as NSString as CFString

    static func settingChanged() {
        Preferences.micKeyMutesMicrophone ? apply() : release()
    }

    static func release() {
        let current = read()
        let next = MicKeyMapping.removing(current)
        guard next.count != current.count else { return }
        write(next)
    }

    private static func apply() {
        write(MicKeyMapping.adding(read()))
    }

    private static func read() -> [[String: UInt64]] {
        let client = IOHIDEventSystemClientCreateSimpleClient(kCFAllocatorDefault)
        guard let value = IOHIDEventSystemClientCopyProperty(client, property) as? [[String: Any]] else { return [] }
        return value.map { $0.compactMapValues { ($0 as? NSNumber)?.uint64Value } }
    }

    private static func write(_ mappings: [[String: UInt64]]) {
        let client = IOHIDEventSystemClientCreateSimpleClient(kCFAllocatorDefault)
        let value = mappings.map { $0.mapValues { NSNumber(value: $0) } } as NSArray
        guard IOHIDEventSystemClientSetProperty(client, property, value) else {
            Logger.error { "Could not set the HID key mapping for the microphone key" }
            return
        }
        Logger.debug { "Microphone key mapping: \(mappings.count) entries" }
    }
}
