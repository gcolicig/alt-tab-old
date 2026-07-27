import Cocoa

enum InstantSpaces {
    private struct Snapshot {
        let displayId: String
        let currentIndex: Int
        let spaceIds: [CGSSpaceID]

        var spaceCount: Int { spaceIds.count }
    }

    private static let supportedMajorVersion = 26
    private static let gestureVelocity = Double(2000)
    /// The Dock coalesces swipe sequences that arrive back to back, so multi-step switches are paced
    /// and re-checked against the real Space instead of being posted as one burst. Calibrate on Tahoe (S-06).
    private static let stepInterval = TimeInterval(0.035)
    /// Longer than `SpacePredictionPolicy.validity`, so the check after the last step always compares
    /// the target against what the system actually reports and repeats a dropped step.
    private static let settleInterval = TimeInterval(0.6)
    private static let directSwitchVerifyInterval = TimeInterval(0.2)
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
            if switchDirectly(to: plan.targetIndex, snapshot) { return }
            markSequenceInFlight(snapshot.displayId, true)
            // one extra attempt per step absorbs a dropped swipe without letting a blocked switch loop
            step(towards: plan.targetIndex, on: snapshot.displayId, attemptsLeft: plan.steps * 2)
        }
    }

    /// Jumps to the target Space without passing through the ones in between, which is what makes large
    /// jumps flicker. The result is verified: if the Space did not change, the swipe path takes over.
    private static func switchDirectly(to targetIndex: Int, _ snapshot: Snapshot) -> Bool {
        guard InstantSpacesPrivateApi.supportsDirectSwitch,
              (0..<snapshot.spaceCount).contains(targetIndex),
              InstantSpacesPrivateApi.switchDirectly(snapshot.displayId as CFString, to: snapshot.spaceIds[targetIndex]) else { return false }
        DispatchQueue.main.asyncAfter(deadline: .now() + directSwitchVerifyInterval) {
            guard let settled = self.snapshot(), settled.displayId == snapshot.displayId else { return }
            if settled.currentIndex == targetIndex {
                finishSequence(on: snapshot.displayId, settledIndex: targetIndex)
            } else {
                Logger.warning { "direct Space switch did not take effect; falling back to swipes" }
                markSequenceInFlight(snapshot.displayId, true)
                step(towards: targetIndex, on: snapshot.displayId, attemptsLeft: settled.spaceCount * 2)
            }
        }
        return true
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
        let isLastStep = stepIndex == targetIndex
        // release the menubar row as soon as the last swipe is out, so the highlight follows the arrival
        // instead of the later verification pass
        markSequenceInFlight(displayId, !isLastStep)
        let delay = isLastStep ? settleInterval : stepInterval
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            step(towards: targetIndex, on: displayId, attemptsLeft: attemptsLeft - 1)
        }
    }

    /// Called when Space indexes lose their meaning: display reconfiguration and wake.
    static func synchronize() {
        predictionLock.lock()
        predictions.removeAll(keepingCapacity: true)
        histories.removeAll(keepingCapacity: true)
        displaysWithSequenceInFlight.removeAll(keepingCapacity: true)
        predictionLock.unlock()
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
        return Snapshot(displayId: displayId as String, currentIndex: currentIndex, spaceIds: Array(spaceIds))
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

    private static func clearPrediction(for displayId: String) {
        predictionLock.lock()
        predictions[displayId] = nil
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
        DispatchQueue.main.async { Menubar.refreshSpaces() }
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
