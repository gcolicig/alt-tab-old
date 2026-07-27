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
            markSequenceInFlight(snapshot.displayId, true)
            if plan.steps > 1 {
                beginTraversalCover()
            }
            // one extra attempt per step absorbs a dropped swipe without letting a blocked switch loop
            step(towards: plan.targetIndex, on: snapshot.displayId, attemptsLeft: plan.steps * 2)
        }
    }

    /// Posts one swipe at a time and re-reads the real Space between steps, so a coalesced or dropped
    /// swipe cannot desynchronize the following steps. The target index belongs to the display the
    /// sequence started on; moving the cursor to another display stops it rather than switching there.
    private static func step(towards targetIndex: Int, on displayId: String, attemptsLeft: Int) {
        guard attemptsLeft > 0, let snapshot = snapshot(), snapshot.displayId == displayId else {
            finishSequence(on: displayId, settledIndex: nil)
            return
        }
        let baseIndex = predictedIndex(snapshot)
        guard let direction = SpaceSwitchPlanner.stepDirection(
            currentIndex: baseIndex, targetIndex: targetIndex, spaceCount: snapshot.spaceCount) else {
            finishSequence(on: displayId, settledIndex: snapshot.currentIndex)
            return
        }
        guard postStep(direction) else {
            finishSequence(on: displayId, settledIndex: nil)
            return
        }
        let stepIndex = direction == .right ? baseIndex + 1 : baseIndex - 1
        setPrediction(SpacePrediction(sourceIndex: snapshot.currentIndex, targetIndex: stepIndex, timestamp: now()), for: displayId)
        if stepIndex == targetIndex {
            // the sequence stays in flight until arrival is observed: the swipes are asynchronous, and
            // releasing the menubar row on posting let the trailing notifications repaint every
            // intermediate Space. Poll briefly so the highlight still follows arrival closely.
            verifyArrival(of: targetIndex, on: displayId, attemptsLeft: attemptsLeft - 1, checksLeft: settleCheckCount)
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + stepInterval) {
                step(towards: targetIndex, on: displayId, attemptsLeft: attemptsLeft - 1)
            }
        }
    }

    private static func verifyArrival(of targetIndex: Int, on displayId: String, attemptsLeft: Int, checksLeft: Int) {
        DispatchQueue.main.asyncAfter(deadline: .now() + settleCheckInterval) {
            guard let snapshot = snapshot(), snapshot.displayId == displayId else {
                finishSequence(on: displayId, settledIndex: nil)
                return
            }
            if snapshot.currentIndex == targetIndex {
                finishSequence(on: displayId, settledIndex: targetIndex)
            } else if checksLeft > 1 {
                verifyArrival(of: targetIndex, on: displayId, attemptsLeft: attemptsLeft, checksLeft: checksLeft - 1)
            } else {
                // the last swipe was dropped: retry through the normal step path
                step(towards: targetIndex, on: displayId, attemptsLeft: attemptsLeft)
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
        predictionLock.unlock()
        DispatchQueue.main.async { endTraversalCover() }
    }

    private static var isSupportedOperatingSystem: Bool {
        ProcessInfo.processInfo.operatingSystemVersion.majorVersion == supportedMajorVersion
    }

    private static func snapshot() -> Snapshot? {
        Spaces.refresh()
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
    private static func finishSequence(on displayId: String, settledIndex: Int?) {
        predictionLock.lock()
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

    static func noteSystemSpaceChange() {
        guard let snapshot = snapshot() else { return }
        predictionLock.lock()
        let isInFlight = displaysWithSequenceInFlight.contains(snapshot.displayId)
        if !isInFlight {
            histories[snapshot.displayId, default: SpaceHistory()].record(snapshot.currentIndex)
        }
        predictionLock.unlock()
    }

    private static func markSequenceInFlight(_ displayId: String, _ inFlight: Bool) {
        predictionLock.lock()
        if inFlight {
            displaysWithSequenceInFlight.insert(displayId)
        } else {
            displaysWithSequenceInFlight.remove(displayId)
        }
        predictionLock.unlock()
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
