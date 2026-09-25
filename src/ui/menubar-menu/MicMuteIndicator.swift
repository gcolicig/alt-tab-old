import Cocoa
import CoreAudio

/// Shows a muted microphone and muted sound in the menu bar, by AltTab+ or anyone else. The icons sit in
/// AltTab+'s own status item, between its icon and the Spaces row; clicking one unmutes. Only when the
/// AltTab+ icon itself is hidden does a muted microphone fall back to a status item of its own.
/// CoreAudio listeners run only while the setting is on (Q-10), and they follow all available audio devices.
enum MicMuteIndicator {
    private static var fallbackItem: NSStatusItem?
    private static var observedInputDevices = Set<AudioObjectID>()
    private static var observedOutputDevices = Set<AudioObjectID>()
    private static var isRunning = false
    private(set) static var inputMuted = false
    private(set) static var outputMuted = false
    private static let listener: AudioObjectPropertyListenerBlock = { _, _ in refresh() }
    private static let deviceListener: AudioObjectPropertyListenerBlock = { _, _ in followAudioDevices() }

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
        followAudioDevices()
    }

    static func stop() {
        guard isRunning else { return }
        isRunning = false
        systemAddresses().forEach { address in
            var address = address
            AudioObjectRemovePropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &address, DispatchQueue.main, deviceListener)
        }
        observeInputs([])
        observeOutputs([])
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

    private static func followAudioDevices() {
        observeInputs(AudioMute.inputDevices())
        observeOutputs(AudioMute.outputDevices())
        refresh()
    }

    private static func observeInputs(_ devices: [AudioObjectID]) {
        let next = Set(devices)
        guard next != observedInputDevices else { return }
        deviceAddresses(input: true).forEach { address in
            var address = address
            observedInputDevices.subtracting(next).forEach { AudioObjectRemovePropertyListenerBlock($0, &address, DispatchQueue.main, listener) }
            next.subtracting(observedInputDevices).forEach {
                if AudioObjectHasProperty($0, &address) { AudioObjectAddPropertyListenerBlock($0, &address, DispatchQueue.main, listener) }
            }
        }
        observedInputDevices = next
    }

    private static func observeOutputs(_ devices: [AudioObjectID]) {
        let next = Set(devices)
        guard next != observedOutputDevices else { return }
        deviceAddresses(input: false).forEach { address in
            var address = address
            observedOutputDevices.subtracting(next).forEach { AudioObjectRemovePropertyListenerBlock($0, &address, DispatchQueue.main, listener) }
            next.subtracting(observedOutputDevices).forEach {
                if AudioObjectHasProperty($0, &address) { AudioObjectAddPropertyListenerBlock($0, &address, DispatchQueue.main, listener) }
            }
        }
        observedOutputDevices = next
    }

    /// Volume is watched too, because a microphone without a mute control is muted through its volume.
    private static func deviceAddresses(input: Bool) -> [AudioObjectPropertyAddress] {
        let scope = input ? kAudioObjectPropertyScopeInput : kAudioObjectPropertyScopeOutput
        let selectors = input ? [kAudioDevicePropertyMute, kAudioDevicePropertyVolumeScalar] : [kAudioDevicePropertyMute]
        return selectors.map { AudioObjectPropertyAddress(mSelector: $0, mScope: scope, mElement: kAudioObjectPropertyElementMain) }
    }

    private static func systemAddresses() -> [AudioObjectPropertyAddress] {
        [kAudioHardwarePropertyDevices].map {
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
        item.button?.image = MuteIcon.input.coloredImage
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

    var color: NSColor {
        let dark = NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        switch self {
        case .input: return dark ? NSColor(srgbRed: 1, green: 0.27, blue: 0.23, alpha: 1) : NSColor(srgbRed: 0.55, green: 0.08, blue: 0.08, alpha: 1)
        case .output: return dark ? NSColor(srgbRed: 0.19, green: 0.82, blue: 0.35, alpha: 1) : NSColor(srgbRed: 0.07, green: 0.42, blue: 0.16, alpha: 1)
        }
    }

    var coloredImage: NSImage? {
        guard let image else { return nil }
        let colored = NSImage(size: image.size)
        colored.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: image.size))
        color.set()
        NSRect(origin: .zero, size: image.size).fill(using: .sourceAtop)
        colored.unlockFocus()
        colored.isTemplate = false
        return colored
    }
}
