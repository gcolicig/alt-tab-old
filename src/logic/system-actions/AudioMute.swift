import CoreAudio
import Foundation

/// Story 14E. Mute through CoreAudio on the default device. A microphone without a mute control is muted
/// by its input volume instead; that simulated mute is the only state AltTab+ gives back on quit.
enum AudioMute {
    private static var simulatedInputMute: (device: AudioObjectID, volume: Float32)?
    private static var defaultInputListener: AudioObjectPropertyListenerBlock?

    static func isMuted(input: Bool) -> Bool {
        guard let device = defaultDevice(input: input) else { return false }
        if input, let simulated = simulatedInputMute, simulated.device == device { return true }
        return readUInt32(device, kAudioDevicePropertyMute, scope(input)) == 1
    }

    static func isAvailable(input: Bool) -> Bool {
        guard let device = defaultDevice(input: input) else { return false }
        return isSettable(device, kAudioDevicePropertyMute, scope(input)) || (input && isSettable(device, kAudioDevicePropertyVolumeScalar, scope(input)))
    }

    static func toggle(input: Bool) {
        guard let device = defaultDevice(input: input) else { return }
        let muted = isMuted(input: input)
        if isSettable(device, kAudioDevicePropertyMute, scope(input)) {
            writeUInt32(device, kAudioDevicePropertyMute, scope(input), muted ? 0 : 1)
        } else if input {
            muted ? restoreSimulatedInputMute() : simulateInputMute(device)
        }
    }

    static func restoreOnQuit() {
        restoreSimulatedInputMute()
    }

    private static func simulateInputMute(_ device: AudioObjectID) {
        guard let volume = readFloat(device, kAudioDevicePropertyVolumeScalar, scope(true)) else { return }
        simulatedInputMute = (device, volume)
        writeFloat(device, kAudioDevicePropertyVolumeScalar, scope(true), 0)
        observeDefaultInput(true)
        MicMuteIndicator.refresh()
    }

    private static func restoreSimulatedInputMute() {
        guard let simulated = simulatedInputMute else { return }
        writeFloat(simulated.device, kAudioDevicePropertyVolumeScalar, scope(true), simulated.volume)
        simulatedInputMute = nil
        observeDefaultInput(false)
        MicMuteIndicator.refresh()
    }

    /// A device switch while the volume stands in for mute would leave the old device silent without any
    /// sign of it, so the old volume comes back first.
    private static func observeDefaultInput(_ enabled: Bool) {
        var address = globalAddress(kAudioHardwarePropertyDefaultInputDevice)
        if enabled, defaultInputListener == nil {
            let listener: AudioObjectPropertyListenerBlock = { _, _ in DispatchQueue.main.async { restoreSimulatedInputMute() } }
            defaultInputListener = listener
            AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &address, DispatchQueue.main, listener)
        } else if !enabled, let listener = defaultInputListener {
            AudioObjectRemovePropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &address, DispatchQueue.main, listener)
            defaultInputListener = nil
        }
    }

    private static func scope(_ input: Bool) -> AudioObjectPropertyScope {
        input ? kAudioObjectPropertyScopeInput : kAudioObjectPropertyScopeOutput
    }

    private static func globalAddress(_ selector: AudioObjectPropertySelector) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
    }

    static func defaultInputDevice() -> AudioObjectID? {
        defaultDevice(input: true)
    }

    static func defaultOutputDevice() -> AudioObjectID? {
        defaultDevice(input: false)
    }

    private static func defaultDevice(input: Bool) -> AudioObjectID? {
        var address = globalAddress(input ? kAudioHardwarePropertyDefaultInputDevice : kAudioHardwarePropertyDefaultOutputDevice)
        var device = AudioObjectID(0)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        let status = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &device)
        return status == noErr && device != 0 ? device : nil
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
