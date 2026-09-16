import Cocoa

/// Story 14K. Swallows every keyboard event while on. Three ways out, all always armed: the emergency
/// shortcut (recognised here, because the Carbon hot key never sees a swallowed key), the menu, and typing
/// `unlock`. A tap that fails ends Cat Mode visibly instead of silently no longer locking.
enum CatMode {
    private static var eventTap: CFMachPort?
    private static var runLoopSource: CFRunLoopSource?
    private static var matcher = UnlockSequenceMatcher()
    private static var autoEnd: DispatchWorkItem?
    private static var overlays = [NSPanel]()
    private static var observers = [(NotificationCenter, NSObjectProtocol)]()
    private(set) static var isOn = false

    static func toggle() {
        isOn ? stop(reason: nil) : start()
    }

    static func availability() -> ActionAvailability {
        guard !Preferences.inputModulesSafeMode else {
            return .unavailable(NSLocalizedString("Input extensions are in safe mode.", comment: ""))
        }
        return .available
    }

    static func start() {
        guard !isOn, availability().isAvailable else { return NSSound.beep() }
        guard createTap() else {
            return TransientNotice.show(NSLocalizedString("Cat Mode could not start: the keyboard could not be locked.", comment: ""))
        }
        isOn = true
        matcher = UnlockSequenceMatcher()
        showOverlays()
        observeSessionEnds()
        scheduleAutoEnd()
    }

    static func stop(reason: String?) {
        guard isOn else { return }
        isOn = false
        removeTap()
        autoEnd?.cancel()
        autoEnd = nil
        overlays.forEach { $0.orderOut(nil) }
        overlays.removeAll()
        observers.forEach { $0.0.removeObserver($0.1) }
        observers.removeAll()
        TransientNotice.show(reason ?? NSLocalizedString("Cat Mode is off. The keyboard works again.", comment: ""))
    }

    private static func createTap() -> Bool {
        let mask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue) | (1 << CGEventType.flagsChanged.rawValue)
        guard let tap = CGEvent.tapCreate(tap: .cghidEventTap, place: .headInsertEventTap, options: .defaultTap,
            eventsOfInterest: CGEventMask(mask), callback: handleEvent, userInfo: nil) else { return false }
        let source = CFMachPortCreateRunLoopSource(nil, tap, 0)
        CFRunLoopAddSource(BackgroundWork.keyboardAndMouseAndTrackpadEventsThread.runLoop, source, .commonModes)
        eventTap = tap
        runLoopSource = source
        return true
    }

    private static func removeTap() {
        guard let tap = eventTap else { return }
        CGEvent.tapEnable(tap: tap, enable: false)
        if let source = runLoopSource {
            CFRunLoopRemoveSource(BackgroundWork.keyboardAndMouseAndTrackpadEventsThread.runLoop, source, .commonModes)
        }
        CFMachPortInvalidate(tap)
        eventTap = nil
        runLoopSource = nil
    }

    private static let handleEvent: CGEventTapCallBack = { _, type, cgEvent, _ in
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            DispatchQueue.main.async { stop(reason: NSLocalizedString("Cat Mode ended because the keyboard lock stopped responding.", comment: "")) }
            return Unmanaged.passUnretained(cgEvent)
        }
        guard type == .keyDown else { return nil }
        let keyCode = cgEvent.getIntegerValueField(.keyboardEventKeycode)
        if CatModePanic.isEmergencyShortcut(keyCode: keyCode, flags: cgEvent.flags.rawValue) {
            DispatchQueue.main.async {
                stop(reason: nil)
                KeyboardEvents.triggerEmergencyStop()
            }
            return nil
        }
        if let character = typedCharacter(cgEvent), matcher.feed(character) {
            DispatchQueue.main.async { stop(reason: nil) }
        }
        return nil
    }

    private static func typedCharacter(_ cgEvent: CGEvent) -> Character? {
        var length = 0
        var chars = [UniChar](repeating: 0, count: 4)
        cgEvent.keyboardGetUnicodeString(maxStringLength: chars.count, actualStringLength: &length, unicodeString: &chars)
        guard length > 0 else { return nil }
        return String(utf16CodeUnits: chars, count: length).first
    }

    private static func scheduleAutoEnd() {
        let item = DispatchWorkItem { stop(reason: NSLocalizedString("Cat Mode ended automatically.", comment: "")) }
        autoEnd = item
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(Preferences.catModeMinutes * 60), execute: item)
    }

    /// Q-15: sleep, a locked screen, a user switch or a lost permission all end the lock.
    private static func observeSessionEnds() {
        let workspace = NSWorkspace.shared.notificationCenter
        [NSWorkspace.willSleepNotification, NSWorkspace.screensDidSleepNotification, NSWorkspace.sessionDidResignActiveNotification].forEach {
            observers.append((workspace, workspace.addObserver(forName: $0, object: nil, queue: .main) { _ in stop(reason: nil) }))
        }
        let distributed = DistributedNotificationCenter.default()
        observers.append((distributed, distributed.addObserver(forName: Notification.Name("com.apple.screenIsLocked"), object: nil, queue: .main) { _ in stop(reason: nil) }))
    }

    private static func showOverlays() {
        overlays = NSScreen.screens.map(makeOverlay)
        overlays.forEach { $0.orderFrontRegardless() }
    }

    private static func makeOverlay(_ screen: NSScreen) -> NSPanel {
        let size = CGSize(width: 520, height: 44)
        let frame = CGRect(x: screen.frame.midX - size.width / 2, y: screen.visibleFrame.minY + 40, width: size.width, height: size.height)
        let panel = NSPanel(contentRect: frame, styleMask: [.nonactivatingPanel, .borderless], backing: .buffered, defer: false)
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        panel.contentView = overlayView(size)
        return panel
    }

    private static func overlayView(_ size: CGSize) -> NSView {
        let effect = NSVisualEffectView(frame: CGRect(origin: .zero, size: size))
        effect.material = .hudWindow
        effect.state = .active
        effect.wantsLayer = true
        effect.layer?.cornerRadius = 10
        let label = NSTextField(labelWithString: NSLocalizedString("🐈 Cat Mode — the keyboard is locked. Click the menu or type “unlock”.", comment: ""))
        label.alignment = .center
        label.frame = CGRect(x: 12, y: (size.height - 20) / 2, width: size.width - 24, height: 20)
        effect.addSubview(label)
        return effect
    }
}
