import Cocoa

/// The first module in AltTab+ with a permanent mouse tap that consumes events, so the safety rules matter
/// more than the feature. Three invariants hold at all times:
///
/// 1. The tap exists only while the module is enabled, and passes every event through untouched unless a
///    session is genuinely active. An unarmed tap must be indistinguishable from no tap.
/// 2. No AX work happens inside the callback (Q-02, Q-16). The callback publishes state; the queue writes.
/// 3. Every exit path — safe mode, emergency shortcut, circuit breaker, permission loss — ends the session
///    without writing a frame.
enum WindowDragEvents {
    private static var eventTap: CFMachPort?
    /// Touched from the tap callback on the main runloop and from the AX queue, so every read and write
    /// goes through `stateLock`. A torn read here would strand a session in `dragging` with no way out.
    private static let stateLock = NSLock()
    private static var unsafeState = DragSessionState.idle
    private static var circuitBreaker = InputTapCircuitBreaker()
    private static var window: AXUIElement?
    private static var windowPid: pid_t?
    private static var originWindowFrame: CGRect?
    private static var originMouse: CGPoint?
    private static var coalescer = AxWriteCoalescer()
    private static var diagnostics = AxDiagnosticsRing()
    private static var snapTarget = DragSnapTarget.none
    private static var snapFrame: CGRect?
    /// When the cursor first reached the current edge, so a shared edge can require dwell.
    private static var edgeEnteredAt: TimeInterval?
    private static var edgeSide: DragSnapTarget = .none
    private static let stabilityWindowSeconds = 5.0
    /// The preference stores an index into `DragModifierPreference.selectable`, not a raw value: writing
    /// the case name here would leave the emergency path relying on a parse failure resetting to default.
    private static let disabledModifierIndex = String(DragModifierPreference.selectable.firstIndex(of: .disabled) ?? 0)

    static var isEnabled: Bool {
        Preferences.windowDragModifier.isEnabled && !Preferences.inputModulesSafeMode
    }

    /// `announceSuppression` is set only when the user just picked a modifier. Safe mode silently keeping
    /// the module off is how a chosen modifier ends up looking broken: the dropdown says the feature is on
    /// while nothing happens. At launch the notice would be noise, so it stays off there.
    static func modifierPreferenceChanged(announceSuppression: Bool = false) {
        guard Preferences.windowDragModifier.isEnabled else {
            stop()
            return
        }
        guard !Preferences.inputModulesSafeMode else {
            stop()
            if announceSuppression {
                TransientNotice.show(NSLocalizedString("Input extensions are in safe mode, so moving windows stays off. Turn safe mode off to use it.", comment: ""))
            }
            return
        }
        start()
    }

    static func disableForSafety() {
        Preferences.set("windowDragModifier", disabledModifierIndex, false)
        Preferences.set("windowDragArmingMarker", "false", false)
        stop()
    }

    private static func start() {
        guard eventTap == nil else { return }
        // written before the tap exists: a crash or hang while arming leaves it behind, and the next launch
        // disables the module instead of arming it again
        Preferences.set("windowDragArmingMarker", "true", false)
        let mask = [CGEventType.leftMouseDown, .leftMouseDragged, .leftMouseUp, .flagsChanged]
            .reduce(CGEventMask(0)) { $0 | (1 << $1.rawValue) }
        eventTap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
                                     eventsOfInterest: mask, callback: handleEvent, userInfo: nil)
        guard let eventTap else {
            Logger.error { "Window drag tap could not be created; leaving the module off" }
            Preferences.set("windowDragArmingMarker", "false", false)
            Preferences.set("windowDragModifier", disabledModifierIndex, false)
            return
        }
        CFRunLoopAddSource(CFRunLoopGetMain(), CFMachPortCreateRunLoopSource(nil, eventTap, 0), .commonModes)
        DispatchQueue.main.asyncAfter(deadline: .now() + stabilityWindowSeconds) {
            Preferences.set("windowDragArmingMarker", "false", false)
        }
    }

    private static func stop() {
        endSession()
        guard let tap = eventTap else { return }
        CGEvent.tapEnable(tap: tap, enable: false)
        CFMachPortInvalidate(tap)
        eventTap = nil
    }

    private static let handleEvent: CGEventTapCallBack = { _, type, cgEvent, _ in
        switch type {
            case .tapDisabledByUserInput, .tapDisabledByTimeout: return handleTapFailure(cgEvent)
            case .flagsChanged: return handleFlagsChanged(cgEvent)
            case .leftMouseDown: return handleMouseDown(cgEvent)
            case .leftMouseDragged: return handleMouseDragged(cgEvent)
            case .leftMouseUp: return handleMouseUp(cgEvent)
            default: return Unmanaged.passUnretained(cgEvent)
        }
    }

    /// Q-04 and Q-12: the first failure may re-enable, a repeat inside the window disables the module
    /// visibly rather than looping.
    private static func handleTapFailure(_ cgEvent: CGEvent) -> Unmanaged<CGEvent> {
        endSession()
        if circuitBreaker.recordFailure(at: ProcessInfo.processInfo.systemUptime) == .trip {
            DispatchQueue.main.async {
                disableForSafety()
                Logger.error { "Window drag was disabled after repeated mouse event tap failures" }
            }
        } else if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: true)
        }
        return Unmanaged.passUnretained(cgEvent)
    }

    private static func handleFlagsChanged(_ cgEvent: CGEvent) -> Unmanaged<CGEvent> {
        let engaged = Preferences.windowDragModifier.matches(NSEvent.ModifierFlags(rawValue: UInt(cgEvent.flags.rawValue)))
        advance(engaged ? .modifierEngaged : .modifierReleased)
        // never consumed: the modifier keeps its normal meaning for every other app
        return Unmanaged.passUnretained(cgEvent)
    }

    private static func handleMouseDown(_ cgEvent: CGEvent) -> Unmanaged<CGEvent>? {
        guard state == .armed else { return Unmanaged.passUnretained(cgEvent) }
        advance(.mouseDown)
        let location = cgEvent.location
        // resolution makes blocking AX calls and must not run in the callback
        AXCallScheduler.shared.submit { resolveOnQueue(location) }
        return nil
    }

    private static func handleMouseDragged(_ cgEvent: CGEvent) -> Unmanaged<CGEvent>? {
        guard state == .dragging else { return Unmanaged.passUnretained(cgEvent) }
        publishTarget(cgEvent.location)
        return nil
    }

    private static func handleMouseUp(_ cgEvent: CGEvent) -> Unmanaged<CGEvent>? {
        guard DragSessionMachine.isActive(state) else { return Unmanaged.passUnretained(cgEvent) }
        let reached = advance(.mouseUp)
        AXCallScheduler.shared.submit { finishOnQueue(reached) }
        return nil
    }

    private static func resolveOnQueue(_ location: CGPoint) {
        guard state == .resolving, let resolved = CursorWindowResolver.resolveElement(at: location),
              let attributes = try? resolved.element.attributes([kAXPositionAttribute, kAXSizeAttribute]),
              let position = attributes.position, let size = attributes.size else {
            advance(.windowUnresolved)
            return
        }
        window = resolved.element
        windowPid = resolved.pid
        originWindowFrame = CGRect(origin: position, size: size)
        originMouse = location
        coalescer = AxWriteCoalescer()
        advance(.windowResolved)
    }

    private static func publishTarget(_ location: CGPoint) {
        guard let origin = originWindowFrame, let start = originMouse else { return }
        updateSnapTarget(location)
        let target = CGRect(x: origin.minX + location.x - start.x, y: origin.minY + location.y - start.y,
                            width: origin.width, height: origin.height)
        guard let due = coalescer.submit(target, now: ProcessInfo.processInfo.systemUptime) else { return }
        AXCallScheduler.shared.submit { writeOnQueue(due) }
    }

    private static func writeOnQueue(_ frame: CGRect) {
        applyFrame(frame)
        guard let next = coalescer.completed(now: ProcessInfo.processInfo.systemUptime) else { return }
        AXCallScheduler.shared.submit { writeOnQueue(next) }
    }

    private static func finishOnQueue(_ reached: DragSessionState) {
        defer { endSession() }
        guard DragSessionMachine.mayApplyFrame(reached) else { return }
        // an active snap target wins over the freely dragged position: it is what the user aimed at
        if let snapFrame {
            applyFrame(snapFrame)
            return
        }
        if let last = coalescer.flush(now: ProcessInfo.processInfo.systemUptime) {
            applyFrame(last)
        }
    }

    /// Recomputed per drag event against the display under the cursor, so dragging onto another screen
    /// re-evaluates against that screen's geometry rather than the one the drag started on.
    private static func updateSnapTarget(_ location: CGPoint) {
        guard let screen = quartzVisibleFrame(containing: location) else {
            clearSnap()
            return
        }
        let now = ProcessInfo.processInfo.systemUptime
        let side = DragSnapPolicy.edge(location, screen)
        guard side != .none else {
            clearSnap()
            return
        }
        if edgeSide != side {
            edgeSide = side
            edgeEnteredAt = now
        }
        let frames = quartzVisibleFrames()
        let confirmed = DragSnapPolicy.target(DragSnapContext(cursor: location, visibleFrame: screen,
                                                              hasNeighbourLeft: DragScreenNeighbours.hasNeighbour(left: true, of: screen, among: frames),
                                                              hasNeighbourRight: DragScreenNeighbours.hasNeighbour(left: false, of: screen, among: frames),
                                                              dwellElapsed: now - (edgeEnteredAt ?? now)))
        snapTarget = confirmed
        snapFrame = DragSnapPolicy.frame(confirmed, in: screen)
        presentOverlay()
    }

    private static func clearSnap() {
        snapTarget = .none
        snapFrame = nil
        edgeSide = .none
        edgeEnteredAt = nil
        presentOverlay()
    }

    /// The overlay is AppKit and belongs on the main thread. The drag events already arrive there, but the
    /// session also ends from the AX queue, so the hop is not optional.
    private static func presentOverlay() {
        let frame = snapFrame
        let show = { frame.map { DragSnapOverlay.show(quartzFrame: $0) } ?? DragSnapOverlay.hide() }
        Thread.isMainThread ? show() : DispatchQueue.main.async(execute: show)
    }

    private static func quartzScreens() -> [DragScreenGeometry] {
        guard let primaryFrame = NSScreen.screens.first?.frame else { return [] }
        let toQuartz = { (rect: CGRect) in
            CGRect(x: rect.minX, y: primaryFrame.maxY - rect.maxY, width: rect.width, height: rect.height)
        }
        return NSScreen.screens.map { DragScreenGeometry(full: toQuartz($0.frame), visible: toQuartz($0.visibleFrame)) }
    }

    private static func quartzVisibleFrames() -> [CGRect] {
        quartzScreens().map { $0.visible }
    }

    private static func quartzVisibleFrame(containing point: CGPoint) -> CGRect? {
        DragScreenLookup.visibleFrame(containing: point, screens: quartzScreens())
    }

    private static func applyFrame(_ frame: CGRect) {
        guard let window, let pid = windowPid else { return }
        // Chromium reflows and fights the write while its enhanced-interface flag is on
        AxAppCompatibility.withEnhancedUserInterfaceSuspended(pid) { try? window.setFrame(frame) }
        let actual = try? window.attributes([kAXPositionAttribute, kAXSizeAttribute])
        let result = (actual?.position).flatMap { position in (actual?.size).map { CGRect(origin: position, size: $0) } }
        let bundleId = NSRunningApplication(processIdentifier: pid)?.bundleIdentifier ?? ""
        diagnostics.record(AxDiagnosticEntry(windowId: (try? window.cgWindowId()) ?? 0, bundleId: bundleId,
                                             displayIndex: 0, proposed: frame, result: result))
    }

    private static var state: DragSessionState {
        stateLock.lock()
        defer { stateLock.unlock() }
        return unsafeState
    }

    /// Returns the state the session actually moved to, so a caller can act on the transition it caused
    /// rather than on a value another thread may already have replaced.
    @discardableResult
    private static func advance(_ event: DragSessionEvent) -> DragSessionState {
        stateLock.lock()
        defer { stateLock.unlock() }
        guard let next = DragSessionMachine.next(unsafeState, event) else { return unsafeState }
        unsafeState = next
        return next
    }

    private static func endSession() {
        stateLock.lock()
        unsafeState = .idle
        stateLock.unlock()
        window = nil
        windowPid = nil
        originWindowFrame = nil
        originMouse = nil
        coalescer = AxWriteCoalescer()
        snapTarget = .none
        snapFrame = nil
        edgeSide = .none
        edgeEnteredAt = nil
        DispatchQueue.main.async { DragSnapOverlay.dismiss() }
    }
}
