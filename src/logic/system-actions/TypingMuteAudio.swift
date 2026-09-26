import CoreAudio
import Foundation

/// The CoreAudio side of `TypingMute`. Everything here runs on `TypingMute.queue`: listeners are delivered
/// there, and the plan is built there so a key press costs one write per device and no lookups.
enum TypingMuteAudio {
    private static let input = kAudioObjectPropertyScopeInput
    /// The block does not name the device, and removing a listener needs the same block, so one is kept per device.
    private static var deviceListeners = [AudioObjectID: AudioObjectPropertyListenerBlock]()
    private static var isObserving = false
    private static let systemListener: AudioObjectPropertyListenerBlock = { _, _ in followDevices() }

    static func startObserving() {
        guard !isObserving else { return }
        isObserving = true
        systemAddresses().forEach { address in
            var address = address
            AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &address, TypingMute.queue, systemListener)
        }
        followDevices()
    }

    static func stopObserving() {
        guard isObserving else { return }
        isObserving = false
        systemAddresses().forEach { address in
            var address = address
            AudioObjectRemovePropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &address, TypingMute.queue, systemListener)
        }
        observe([])
    }

    /// Running inputs, the default input first: with several, it is the one most likely to carry the call.
    static func targets() -> [TypingMuteTarget] {
        let defaultInput = defaultInputDevice()
        return AudioMute.inputDevices()
            .filter(isRunningSomewhere)
            .sorted { $0 == defaultInput && $1 != defaultInput }
            .compactMap(target)
    }

    static func anyInputRunning() -> Bool {
        AudioMute.inputDevices().contains(where: isRunningSomewhere)
    }

    static func isRunningSomewhere(_ device: AudioObjectID) -> Bool {
        var address = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        var value = UInt32(0)
        var size = UInt32(MemoryLayout<UInt32>.size)
        return AudioObjectGetPropertyData(device, &address, 0, nil, &size, &value) == noErr && value != 0
    }

    static func read(_ entry: TypingMuteOwnedDevice) -> Float32? {
        let device = AudioObjectID(entry.device)
        guard entry.route == .volume else { return AudioMute.readUInt32(device, kAudioDevicePropertyMute, input).map(Float32.init) }
        return AudioMute.readFloat(device, kAudioDevicePropertyVolumeScalar, input)
    }

    static func write(_ entry: TypingMuteOwnedDevice, _ value: Float32) -> Bool {
        let device = AudioObjectID(entry.device)
        guard entry.route == .volume else { return AudioMute.writeUInt32(device, kAudioDevicePropertyMute, input, value < 0.5 ? 0 : 1) }
        return AudioMute.writeFloat(device, kAudioDevicePropertyVolumeScalar, input, value)
    }

    /// True when nothing is left to do: restored, changed by somebody else, or gone.
    static func restore(_ entry: TypingMuteOwnedDevice) -> Bool {
        guard let observed = read(entry) else { return true }
        guard let value = TypingMuteOwnership.restoreValue(entry, observed: observed) else { return true }
        return write(entry, value)
    }

    /// Device ids do not survive a restart of coreaudiod or a replug; the UID does.
    static func recover(_ entry: TypingMuteOwnedDevice) {
        guard let device = device(forUid: entry.uid) else { return }
        let current = TypingMuteOwnedDevice(device: device, uid: entry.uid, route: entry.route, original: entry.original, written: entry.written)
        if !restore(current) { Logger.error { "typing mute: could not recover a device after an unclean exit" } }
    }

    private static func target(_ device: AudioObjectID) -> TypingMuteTarget? {
        guard let uid = uid(device) else { return nil }
        if AudioMute.isSettable(device, kAudioDevicePropertyVolumeScalar, input), let volume = AudioMute.readFloat(device, kAudioDevicePropertyVolumeScalar, input) {
            return TypingMuteTarget(device: device, uid: uid, route: .volume, currentValue: volume)
        }
        guard AudioMute.isSettable(device, kAudioDevicePropertyMute, input), let mute = AudioMute.readUInt32(device, kAudioDevicePropertyMute, input) else { return nil }
        return TypingMuteTarget(device: device, uid: uid, route: .mute, currentValue: Float32(mute))
    }

    private static func followDevices() {
        let devices = Set(AudioMute.inputDevices())
        observe(devices)
        TypingMute.devicesChanged(devices)
    }

    private static func observe(_ devices: Set<AudioObjectID>) {
        Set(deviceListeners.keys).subtracting(devices).forEach(unfollow)
        devices.subtracting(deviceListeners.keys).forEach(follow)
    }

    private static func follow(_ device: AudioObjectID) {
        let listener: AudioObjectPropertyListenerBlock = { _, _ in TypingMute.deviceChanged(device) }
        deviceListeners[device] = listener
        deviceAddresses().forEach { address in
            var address = address
            AudioObjectAddPropertyListenerBlock(device, &address, TypingMute.queue, listener)
        }
    }

    private static func unfollow(_ device: AudioObjectID) {
        guard let listener = deviceListeners.removeValue(forKey: device) else { return }
        deviceAddresses().forEach { address in
            var address = address
            AudioObjectRemovePropertyListenerBlock(device, &address, TypingMute.queue, listener)
        }
    }

    private static func systemAddresses() -> [AudioObjectPropertyAddress] {
        [kAudioHardwarePropertyDevices, kAudioHardwarePropertyDefaultInputDevice].map {
            AudioObjectPropertyAddress(mSelector: $0, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        }
    }

    private static func deviceAddresses() -> [AudioObjectPropertyAddress] {
        [AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain),
         AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyVolumeScalar, mScope: input, mElement: kAudioObjectPropertyElementMain),
         AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyMute, mScope: input, mElement: kAudioObjectPropertyElementMain)]
    }

    private static func defaultInputDevice() -> AudioObjectID? {
        var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultInputDevice, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        var device = AudioObjectID(0)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        return AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &device) == noErr ? device : nil
    }

    private static func uid(_ device: AudioObjectID) -> String? {
        var address = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyDeviceUID, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        var uid: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, &uid) == noErr, let uid else { return nil }
        return uid.takeRetainedValue() as String
    }

    private static func device(forUid uid: String) -> AudioObjectID? {
        var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyTranslateUIDToDevice, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        var qualifier = uid as CFString
        var device = AudioObjectID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        let status = withUnsafeMutablePointer(to: &qualifier) {
            AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, UInt32(MemoryLayout<CFString>.size), $0, &size, &device)
        }
        return status == noErr && device != kAudioObjectUnknown ? device : nil
    }
}
