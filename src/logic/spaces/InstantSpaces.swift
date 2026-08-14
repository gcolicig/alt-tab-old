import Cocoa

enum InstantSpaces {
    private struct Snapshot {
        let displayId: String
        let currentIndex: Int
        let spaceCount: Int
    }

    private static let supportedMajorVersion = 26
    private static let gestureVelocity = Double(2000)
    /// The Dock coalesces swipe sequences that arrive back to back, so multi-step switches are paced
    /// and re-checked against the real Space instead of being posted as one burst. Calibrate on Tahoe (S-06).
    private static let stepInterval = TimeInterval(0.035)
    /// Arrival is polled in short checks; their total span exceeds `SpacePredictionPolicy.validity`,
    /// so a dropped last swipe is always caught against what the system actually reports.
    private static let settleCheckInterval = TimeInterval(0.15)
    private static let settleCheckCount = 4
    private static let predictionLock = NSLock()
    private static var predictions = [String: SpacePrediction]()
    private static var histories = [String: SpaceHistory]()
    private static var displaysWithSequenceInFlight = Set<String>()
    private static var sequenceGenerations = [String: UInt64]()
    private static let eventTypeField = CGEventField(rawValue: 55)
    private static let gestureHidTypeField = CGEventField(rawValue: 110)
    private static let swipeMotionField = CGEventField(rawValue: 123)
    private static let swipeProgressField = CGEventField(rawValue: 124)
    private static let swipeVelocityXField = CGEventField(rawValue: 129)
    private static let swipeVelocityYField = CGEventField(rawValue: 130)
    private static let gesturePhaseField = CGEventField(rawValue: 132)
    private static var fadeToken: CGDisplayFadeReservationToken?

    static func availability(_ action: SpaceAction) -> ActionAvailability {
        let runtimeAvailability = runtimeAvailability()
        guard runtimeAvailability.isAvailable else { return runtimeAvailability }
        guard let snapshot = snapshot(), plan(action, snapshot) != nil else {
            return .unavailable(NSLocalizedString("This Space is not available.", comment: ""))
        }
        return .available
    }

    private static func plan(_ action: SpaceAction, _ snapshot: Snapshot) -> SpaceSwitchPlan? {
        SpaceSwitchPlanner.plan(action,
                                currentIndex: predictedIndex(snapshot),
                                spaceCount: snapshot.spaceCount,
                                previousIndex: previousIndex(for: snapshot.displayId))
    }

    static func runtimeAvailability() -> ActionAvailability {
        guard isSupportedOperatingSystem else {
            return .unavailable(NSLocalizedString("Instant Spaces is unavailable on this macOS version.", comment: ""))
        }
        guard InstantSpacesPrivateApi.isAvailable else {
            return .unavailable(NSLocalizedString("Instant Spaces is unavailable because a required system symbol is missing.", comment: ""))
        }
        guard !dockOverlayIsActive() else {
            return .unavailable(NSLocalizedString("Close Mission Control or App Expose before switching Spaces.", comment: ""))
        }
        return .available
    }

    static func perform(_ action: SpaceAction) {
        DispatchQueue.main.async {
            guard availability(action).isAvailable,
                  let snapshot = snapshot(),
                  let plan = plan(action, snapshot) else { return }
            // a new command supersedes whatever is still running for this display: without that, the
            // older sequence kept stepping towards its own target and dragged the Space back
            let generation = beginSequence(on: snapshot.displayId)
            if plan.steps > 1 {
                beginTraversalCover()
            }
            // one extra attempt per step absorbs a dropped swipe without letting a blocked switch loop
            step(towards: plan.targetIndex, on: snapshot.displayId, generation: generation, attemptsLeft: plan.steps * 2)
        }
    }

    /// Posts one swipe at a time and re-reads the real Space between steps, so a coalesced or dropped
    /// swipe cannot desynchronize the following steps. The target index belongs to the display the
    /// sequence started on; moving the cursor to another display stops it rather than switching there.
    private static func step(towards targetIndex: Int, on displayId: String, generation: UInt64, attemptsLeft: Int) {
        guard isCurrentSequence(generation, on: displayId) else { return }
        guard attemptsLeft > 0, let snapshot = snapshot(), snapshot.displayId == displayId else {
            finishSequence(on: displayId, generation: generation, settledIndex: nil)
            return
        }
        let baseIndex = predictedIndex(snapshot)
        guard let direction = SpaceSwitchPlanner.stepDirection(
            currentIndex: baseIndex, targetIndex: targetIndex, spaceCount: snapshot.spaceCount) else {
            finishSequence(on: displayId, generation: generation, settledIndex: snapshot.currentIndex)
            return
        }
        guard postStep(direction) else {
            finishSequence(on: displayId, generation: generation, settledIndex: nil)
            return
        }
        let stepIndex = direction == .right ? baseIndex + 1 : baseIndex - 1
        setPrediction(SpacePrediction(sourceIndex: snapshot.currentIndex, targetIndex: stepIndex, timestamp: now()), for: displayId)
        if stepIndex == targetIndex {
            // the sequence stays in flight until arrival is observed: the swipes are asynchronous, and
            // releasing the menubar row on posting let the trailing notifications repaint every
            // intermediate Space. Poll briefly so the highlight still follows arrival closely.
            verifyArrival(of: targetIndex, on: displayId, generation: generation, attemptsLeft: attemptsLeft - 1, checksLeft: settleCheckCount)
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + stepInterval) {
                step(towards: targetIndex, on: displayId, generation: generation, attemptsLeft: attemptsLeft - 1)
            }
        }
    }

    private static func verifyArrival(of targetIndex: Int, on displayId: String, generation: UInt64, attemptsLeft: Int, checksLeft: Int) {
        DispatchQueue.main.asyncAfter(deadline: .now() + settleCheckInterval) {
            guard isCurrentSequence(generation, on: displayId) else { return }
            guard let snapshot = snapshot(), snapshot.displayId == displayId else {
                finishSequence(on: displayId, generation: generation, settledIndex: nil)
                return
            }
            if snapshot.currentIndex == targetIndex {
                finishSequence(on: displayId, generation: generation, settledIndex: targetIndex)
            } else if checksLeft > 1 {
                verifyArrival(of: targetIndex, on: displayId, generation: generation, attemptsLeft: attemptsLeft, checksLeft: checksLeft - 1)
            } else {
                // the last swipe was dropped: retry through the normal step path
                step(towards: targetIndex, on: displayId, generation: generation, attemptsLeft: attemptsLeft)
            }
        }
    }

    /// Hides the flicker of a multi-step traversal behind a short system fade: every intermediate Space
    /// is still a real switch, so the frames in between cannot be avoided, only covered. The fade
    /// reservation expires on its own after two seconds, so an aborted sequence cannot leave the
    /// screen dark even if the release is never reached.
    private static func beginTraversalCover() {
        guard fadeToken == nil else { return }
        var token = CGDisplayFadeReservationToken(kCGDisplayFadeReservationInvalidToken)
        guard CGAcquireDisplayFadeReservation(2, &token) == CGError.success else { return }
        fadeToken = token
        CGDisplayFade(token, 0.06,
                      CGDisplayBlendFraction(kCGDisplayBlendNormal), CGDisplayBlendFraction(kCGDisplayBlendSolidColor),
                      0, 0, 0, boolean_t(1))
    }

    private static func endTraversalCover() {
        guard let token = fadeToken else { return }
        fadeToken = nil
        CGDisplayFade(token, 0.15,
                      CGDisplayBlendFraction(kCGDisplayBlendSolidColor), CGDisplayBlendFraction(kCGDisplayBlendNormal),
                      0, 0, 0, boolean_t(0))
        CGReleaseDisplayFadeReservation(token)
    }

    /// Called when Space indexes lose their meaning: display reconfiguration and wake.
    static func synchronize() {
        predictionLock.lock()
        predictions.removeAll(keepingCapacity: true)
        histories.removeAll(keepingCapacity: true)
        displaysWithSequenceInFlight.removeAll(keepingCapacity: true)
        // invalidate running sequences: their target indexes no longer describe the same Spaces
        sequenceGenerations.keys.forEach { sequenceGenerations[$0] = (sequenceGenerations[$0] ?? 0) &+ 1 }
        predictionLock.unlock()
        DispatchQueue.main.async { endTraversalCover() }
    }

    private static var isSupportedOperatingSystem: Bool {
        ProcessInfo.processInfo.operatingSystemVersion.majorVersion == supportedMajorVersion
    }

    private static func snapshot(refreshing: Bool = true) -> Snapshot? {
        if refreshing {
            Spaces.refresh()
        }
        guard let cursorScreen = NSScreen.withMouse(), let cursorDisplayId = cursorScreen.cachedUuid() else { return nil }
        var displayId = cursorDisplayId
        var spaceIds = Spaces.screenSpacesMap[cursorDisplayId]
        if spaceIds == nil, let fallback = Spaces.screenSpacesMap.first {
            displayId = fallback.key
            spaceIds = fallback.value
        }
        guard let spaceIds, !spaceIds.isEmpty,
              let currentSpaceId = InstantSpacesPrivateApi.currentSpaceId(displayId),
              let currentIndex = spaceIds.firstIndex(of: currentSpaceId) else { return nil }
        return Snapshot(displayId: displayId as String, currentIndex: currentIndex, spaceCount: spaceIds.count)
    }

    private static func predictedIndex(_ snapshot: Snapshot) -> Int {
        predictionLock.lock()
        defer { predictionLock.unlock() }
        return SpacePredictionPolicy.baseIndex(
            observedIndex: snapshot.currentIndex, prediction: predictions[snapshot.displayId], now: now())
    }

    private static func setPrediction(_ prediction: SpacePrediction, for displayId: String) {
        predictionLock.lock()
        predictions[displayId] = prediction
        predictionLock.unlock()
    }

    /// Records the Space a display arrived at. Called when one of our sequences settles and, through
    /// `noteSystemSpaceChange`, when the user switches Spaces natively.
    private static func finishSequence(on displayId: String, generation: UInt64, settledIndex: Int?) {
        predictionLock.lock()
        guard sequenceGenerations[displayId] == generation else {
            predictionLock.unlock()
            return
        }
        predictions[displayId] = nil
        displaysWithSequenceInFlight.remove(displayId)
        if let settledIndex {
            histories[displayId, default: SpaceHistory()].record(settledIndex)
        }
        predictionLock.unlock()
        // the menubar row skips its refresh while a sequence runs, so it needs the settled state here
        DispatchQueue.main.async {
            endTraversalCover()
            Menubar.refreshSpaces()
        }
    }

    static var isSwitching: Bool {
        predictionLock.lock()
        defer { predictionLock.unlock() }
        return !displaysWithSequenceInFlight.isEmpty
    }

    /// Called from the Space change notification, which refreshes `Spaces` itself.
    static func noteSystemSpaceChange() {
        guard let snapshot = snapshot(refreshing: false) else { return }
        predictionLock.lock()
        let isInFlight = displaysWithSequenceInFlight.contains(snapshot.displayId)
        if !isInFlight {
            histories[snapshot.displayId, default: SpaceHistory()].record(snapshot.currentIndex)
        }
        predictionLock.unlock()
    }

    /// Starts a sequence and invalidates any older one for the same display.
    private static func beginSequence(on displayId: String) -> UInt64 {
        predictionLock.lock()
        defer { predictionLock.unlock() }
        let generation = (sequenceGenerations[displayId] ?? 0) &+ 1
        sequenceGenerations[displayId] = generation
        displaysWithSequenceInFlight.insert(displayId)
        return generation
    }

    private static func isCurrentSequence(_ generation: UInt64, on displayId: String) -> Bool {
        predictionLock.lock()
        defer { predictionLock.unlock() }
        return sequenceGenerations[displayId] == generation
    }

    private static func previousIndex(for displayId: String) -> Int? {
        predictionLock.lock()
        defer { predictionLock.unlock() }
        return histories[displayId]?.previousIndex
    }

    private static func now() -> TimeInterval {
        ProcessInfo.processInfo.systemUptime
    }

    private static func postStep(_ direction: SpaceSwitchDirection) -> Bool {
        post(.began, direction) && post(.changed, direction) && post(.ended, direction)
    }

    // ─── TEMPORARY SPIKE — Spaces plan, Stufe 1. Delete after the measurement; do not build on this. ───
    // Question under measurement: can the synthetic swipe address a display the cursor is not on?
    // V3 re-checks the 2026-08-06 claim that `event.location` is ignored; V0/V1/V2 measure the warp route.

    enum RemoteSpikeVariant: String, CaseIterable {
        case v3Location = "V3 event.location"
        case v0Warp = "V0 warp, no delay"
        case v1Warp20 = "V1 warp, 20 ms"
        case v1Warp50 = "V1 warp, 50 ms"
        case v1Warp100 = "V1 warp, 100 ms"
        case v2WarpNoSuppression = "V2 warp, suppression 0"
    }

    static func remoteSpike(_ direction: SpaceSwitchDirection, _ variant: RemoteSpikeVariant) {
        DispatchQueue.main.async {
            Spaces.refresh()
            guard let cursorScreen = NSScreen.withMouse(), let cursorUuid = cursorScreen.cachedUuid() else {
                Logger.error { "spike: no cursor display" }
                return
            }
            guard let target = NSScreen.screens.first(where: { $0.cachedUuid() != nil && $0.cachedUuid() != cursorUuid }),
                  let targetNumber = target.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else {
                Logger.error { "spike: needs a second display" }
                return
            }
            let targetCenter = CGPoint(x: CGDisplayBounds(targetNumber).midX, y: CGDisplayBounds(targetNumber).midY)
            Logger.info { "spike \(variant.rawValue) \(direction): cursor=\(cursorUuid) target center=\(targetCenter)" }
            spikeLogAllDisplays("before")
            switch variant {
                case .v3Location:
                    _ = spikePostStep(direction, location: targetCenter, source: nil)
                    spikeVerify()
                case .v0Warp:
                    spikeWarpAndPost(direction, targetCenter, delay: 0, source: nil)
                case .v1Warp20:
                    spikeWarpAndPost(direction, targetCenter, delay: 0.020, source: nil)
                case .v1Warp50:
                    spikeWarpAndPost(direction, targetCenter, delay: 0.050, source: nil)
                case .v1Warp100:
                    spikeWarpAndPost(direction, targetCenter, delay: 0.100, source: nil)
                case .v2WarpNoSuppression:
                    let source = CGEventSource(stateID: .hidSystemState)
                    source?.localEventsSuppressionInterval = 0
                    spikeWarpAndPost(direction, targetCenter, delay: 0, source: source)
            }
        }
    }

    private static func spikeWarpAndPost(_ direction: SpaceSwitchDirection, _ targetCenter: CGPoint, delay: TimeInterval, source: CGEventSource?) {
        guard let origin = CGEvent(source: nil)?.location else {
            Logger.error { "spike: could not read the cursor position" }
            return
        }
        CGWarpMouseCursorPosition(targetCenter)
        let postAndReturn = {
            _ = spikePostStep(direction, location: nil, source: source)
            CGWarpMouseCursorPosition(origin)
            let restored = CGEvent(source: nil)?.location
            Logger.info { "spike: cursor restored to \(String(describing: restored)) (origin was \(origin))" }
            spikeVerify()
        }
        if delay == 0 {
            postAndReturn()
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: postAndReturn)
        }
    }

    private static func spikePostStep(_ direction: SpaceSwitchDirection, location: CGPoint?, source: CGEventSource?) -> Bool {
        spikePost(.began, direction, location, source)
            && spikePost(.changed, direction, location, source)
            && spikePost(.ended, direction, location, source)
    }

    private static func spikePost(_ phase: GesturePhase, _ direction: SpaceSwitchDirection, _ location: CGPoint?, _ source: CGEventSource?) -> Bool {
        guard let eventTypeField, let gestureHidTypeField, let swipeMotionField, let swipeProgressField,
              let swipeVelocityXField, let swipeVelocityYField, let gesturePhaseField,
              let event = CGEvent(source: source) else { return false }
        let sign = direction == .right ? Double(1) : Double(-1)
        event.setIntegerValueField(eventTypeField, value: 30)
        event.setIntegerValueField(gestureHidTypeField, value: 23)
        event.setIntegerValueField(gesturePhaseField, value: phase.rawValue)
        event.setIntegerValueField(swipeMotionField, value: 1)
        event.setDoubleValueField(swipeProgressField, value: sign * Double(Float.leastNonzeroMagnitude))
        event.setDoubleValueField(swipeVelocityXField, value: sign * gestureVelocity)
        event.setDoubleValueField(swipeVelocityYField, value: sign * gestureVelocity)
        if let location {
            event.location = location
        }
        event.post(tap: .cgSessionEventTap)
        return true
    }

    private static func spikeVerify() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            Spaces.refresh()
            spikeLogAllDisplays("after")
        }
    }

    private static func spikeLogAllDisplays(_ label: String) {
        for (displayId, spaceIds) in Spaces.screenSpacesMap {
            let currentId = InstantSpacesPrivateApi.currentSpaceId(displayId)
            let index = currentId.flatMap { spaceIds.firstIndex(of: $0) }
            Logger.info { "spike \(label): display \(displayId) space index \(String(describing: index)) of \(spaceIds.count) (id \(String(describing: currentId)))" }
        }
    }

    // ─── END TEMPORARY SPIKE ───

    private static func post(_ phase: GesturePhase, _ direction: SpaceSwitchDirection) -> Bool {
        guard let eventTypeField,
              let gestureHidTypeField,
              let swipeMotionField,
              let swipeProgressField,
              let swipeVelocityXField,
              let swipeVelocityYField,
              let gesturePhaseField,
              let event = CGEvent(source: nil) else { return false }
        let sign = direction == .right ? Double(1) : Double(-1)
        event.setIntegerValueField(eventTypeField, value: 30)
        event.setIntegerValueField(gestureHidTypeField, value: 23)
        event.setIntegerValueField(gesturePhaseField, value: phase.rawValue)
        event.setIntegerValueField(swipeMotionField, value: 1)
        event.setDoubleValueField(swipeProgressField, value: sign * Double(Float.leastNonzeroMagnitude))
        event.setDoubleValueField(swipeVelocityXField, value: sign * gestureVelocity)
        event.setDoubleValueField(swipeVelocityYField, value: sign * gestureVelocity)
        // Setting `event.location` here is pointless and was measured as such on 2026-08-06: the Dock
        // applies a swipe to the active menubar display, which no property of the event can name.
        event.post(tap: .cgSessionEventTap)
        return true
    }

    private static func dockOverlayIsActive() -> Bool {
        guard let windowInfo = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[CFString: Any]] else { return true }
        let dockLayers = windowInfo.compactMap { window -> Int? in
            guard window[kCGWindowOwnerName] as? String == "Dock" else { return nil }
            return (window[kCGWindowLayer] as? NSNumber)?.intValue
        }
        return SpaceSwitchPlanner.dockOverlayIsActive(dockLayers)
    }

    private enum GesturePhase: Int64 {
        case began = 1
        case changed = 2
        case ended = 4
    }
}
