import Cocoa
import CoreAudio

/// A status item that exists only while the default microphone is muted, by AltTab+ or anyone else.
/// macOS shows muted output in its own volume item but has no equivalent for input. Clicking the item
/// unmutes. CoreAudio listeners run only while the setting is on (Q-10), and they follow a change of the
/// default input device.
enum MicMuteIndicator {
    private static var statusItem: NSStatusItem?
    private static var observedDevice: AudioObjectID?
    private static var isRunning = false
    private static let listener: AudioObjectPropertyListenerBlock = { _, _ in refresh() }
    private static let deviceListener: AudioObjectPropertyListenerBlock = { _, _ in followDefaultDevice() }

    static func preferenceChanged() {
        Preferences.micMuteIndicator ? start() : stop()
    }

    static func start() {
        guard !isRunning else { return }
        isRunning = true
        var address = systemInputAddress()
        AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &address, DispatchQueue.main, deviceListener)
        followDefaultDevice()
    }

    static func stop() {
        guard isRunning else { return }
        isRunning = false
        var address = systemInputAddress()
        AudioObjectRemovePropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &address, DispatchQueue.main, deviceListener)
        observe(nil)
        show(false)
    }

    static func refresh() {
        DispatchQueue.main.async {
            guard isRunning else { return }
            show(AudioMute.isMuted(input: true))
        }
    }

    private static func followDefaultDevice() {
        observe(AudioMute.defaultInputDevice())
        refresh()
    }

    private static func observe(_ device: AudioObjectID?) {
        guard device != observedDevice else { return }
        deviceAddresses().forEach { address in
            var address = address
            if let old = observedDevice { AudioObjectRemovePropertyListenerBlock(old, &address, DispatchQueue.main, listener) }
            if let device, AudioObjectHasProperty(device, &address) { AudioObjectAddPropertyListenerBlock(device, &address, DispatchQueue.main, listener) }
        }
        observedDevice = device
    }

    /// Volume is watched too, because a microphone without a mute control is muted through its volume.
    private static func deviceAddresses() -> [AudioObjectPropertyAddress] {
        [kAudioDevicePropertyMute, kAudioDevicePropertyVolumeScalar].map {
            AudioObjectPropertyAddress(mSelector: $0, mScope: kAudioObjectPropertyScopeInput, mElement: kAudioObjectPropertyElementMain)
        }
    }

    private static func systemInputAddress() -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultInputDevice, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
    }

    private static func show(_ visible: Bool) {
        guard visible else {
            if let item = statusItem { NSStatusBar.system.removeStatusItem(item) }
            statusItem = nil
            return
        }
        guard statusItem == nil else { return }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let image = NSImage(systemSymbolName: "mic.slash.fill", accessibilityDescription: NSLocalizedString("Microphone muted", comment: ""))
        image?.isTemplate = true
        item.button?.image = image
        item.button?.toolTip = NSLocalizedString("Microphone muted — click to unmute", comment: "")
        item.button?.target = ClickTarget.shared
        item.button?.action = #selector(ClickTarget.unmute)
        statusItem = item
    }

    private final class ClickTarget: NSObject {
        static let shared = ClickTarget()

        @objc func unmute() {
            guard AudioMute.isMuted(input: true) else { return }
            AudioMute.toggle(input: true)
            MicMuteIndicator.refresh()
        }
    }
}
