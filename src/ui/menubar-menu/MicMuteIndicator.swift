import Cocoa
import CoreAudio

/// Shows a muted microphone and muted sound in the menu bar, by AltTab+ or anyone else. The icons sit in
/// AltTab+'s own status item, between its icon and the Spaces row; clicking one unmutes. Only when the
/// AltTab+ icon itself is hidden does a muted microphone fall back to a status item of its own.
/// CoreAudio listeners run only while the setting is on (Q-10), and they follow a change of the default
/// devices.
enum MicMuteIndicator {
    private static var fallbackItem: NSStatusItem?
    private static var observedDevices: [Bool: AudioObjectID] = [:]
    private static var isRunning = false
    private(set) static var inputMuted = false
    private(set) static var outputMuted = false
    private static let listener: AudioObjectPropertyListenerBlock = { _, _ in refresh() }
    private static let deviceListener: AudioObjectPropertyListenerBlock = { _, _ in followDefaultDevices() }

    static func preferenceChanged() {
        Preferences.micMuteIndicator ? start() : stop()
    }

    static func start() {
        guard !isRunning else { return }
        isRunning = true
        systemAddresses().forEach { address in
            var address = address
            AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &address, DispatchQueue.main, deviceListener)
        }
        followDefaultDevices()
    }

    static func stop() {
        guard isRunning else { return }
        isRunning = false
        systemAddresses().forEach { address in
            var address = address
            AudioObjectRemovePropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &address, DispatchQueue.main, deviceListener)
        }
        observe(nil, input: true)
        observe(nil, input: false)
        update(input: false, output: false)
    }

    static func refresh() {
        DispatchQueue.main.async {
            guard isRunning else { return }
            update(input: AudioMute.isMuted(input: true), output: AudioMute.isMuted(input: false))
        }
    }

    /// The icons to draw in the row, in order. Empty when nothing is muted or the row cannot host them.
    static var rowIcons: [MuteIcon] {
        guard isRunning else { return [] }
        return (inputMuted ? [MuteIcon.input] : []) + (outputMuted ? [MuteIcon.output] : [])
    }

    static func unmute(_ icon: MuteIcon) {
        let input = icon == .input
        guard AudioMute.isMuted(input: input) else { return }
        AudioMute.toggle(input: input)
        refresh()
    }

    private static func update(input: Bool, output: Bool) {
        guard input != inputMuted || output != outputMuted else { return }
        inputMuted = input
        outputMuted = output
        Menubar.refreshSpaces(spacesAreFresh: true)
        showFallback(input && !Preferences.menubarIconShown)
    }

    private static func followDefaultDevices() {
        observe(AudioMute.defaultInputDevice(), input: true)
        observe(AudioMute.defaultOutputDevice(), input: false)
        refresh()
    }

    private static func observe(_ device: AudioObjectID?, input: Bool) {
        guard device != observedDevices[input] else { return }
        deviceAddresses(input: input).forEach { address in
            var address = address
            if let old = observedDevices[input] { AudioObjectRemovePropertyListenerBlock(old, &address, DispatchQueue.main, listener) }
            if let device, AudioObjectHasProperty(device, &address) { AudioObjectAddPropertyListenerBlock(device, &address, DispatchQueue.main, listener) }
        }
        observedDevices[input] = device
    }

    /// Volume is watched too, because a microphone without a mute control is muted through its volume.
    private static func deviceAddresses(input: Bool) -> [AudioObjectPropertyAddress] {
        let scope = input ? kAudioObjectPropertyScopeInput : kAudioObjectPropertyScopeOutput
        let selectors = input ? [kAudioDevicePropertyMute, kAudioDevicePropertyVolumeScalar] : [kAudioDevicePropertyMute]
        return selectors.map { AudioObjectPropertyAddress(mSelector: $0, mScope: scope, mElement: kAudioObjectPropertyElementMain) }
    }

    private static func systemAddresses() -> [AudioObjectPropertyAddress] {
        [kAudioHardwarePropertyDefaultInputDevice, kAudioHardwarePropertyDefaultOutputDevice].map {
            AudioObjectPropertyAddress(mSelector: $0, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        }
    }

    private static func showFallback(_ visible: Bool) {
        guard visible else {
            if let item = fallbackItem { NSStatusBar.system.removeStatusItem(item) }
            fallbackItem = nil
            return
        }
        guard fallbackItem == nil else { return }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = MuteIcon.input.image
        item.button?.toolTip = MuteIcon.input.tooltip
        item.button?.target = ClickTarget.shared
        item.button?.action = #selector(ClickTarget.unmuteInput)
        fallbackItem = item
    }

    private final class ClickTarget: NSObject {
        static let shared = ClickTarget()

        @objc func unmuteInput() {
            MicMuteIndicator.unmute(.input)
        }
    }
}

enum MuteIcon {
    case input
    case output

    var symbol: String { self == .input ? "mic.slash.fill" : "speaker.slash.fill" }

    var label: String {
        self == .input ? NSLocalizedString("Microphone muted", comment: "") : NSLocalizedString("Sound muted", comment: "")
    }

    var tooltip: String {
        self == .input ? NSLocalizedString("Microphone muted — click to unmute", comment: "") : NSLocalizedString("Sound muted — click to unmute", comment: "")
    }

    var image: NSImage? {
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: label)
        image?.isTemplate = true
        return image
    }
}
