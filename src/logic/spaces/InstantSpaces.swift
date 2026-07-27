import Cocoa

enum InstantSpaces {
    private struct Snapshot {
        let displayId: String
        let currentIndex: Int
        let spaceCount: Int
    }

    private static let supportedMajorVersion = 26
    private static let gestureVelocity = Double(2000)
    private static let predictionLock = NSLock()
    private static var predictions = [String: Int]()
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
        guard let snapshot = snapshot(),
              SpaceSwitchPlanner.plan(action, currentIndex: predictedIndex(snapshot), spaceCount: snapshot.spaceCount) != nil else {
            return .unavailable(NSLocalizedString("This Space is not available.", comment: ""))
        }
        return .available
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
                  let plan = SpaceSwitchPlanner.plan(action, currentIndex: predictedIndex(snapshot), spaceCount: snapshot.spaceCount),
                  post(plan) else { return }
            setPrediction(plan.targetIndex, for: snapshot.displayId)
        }
    }

    static func synchronize() {
        predictionLock.lock()
        predictions.removeAll(keepingCapacity: true)
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
        return Snapshot(displayId: displayId as String, currentIndex: currentIndex, spaceCount: spaceIds.count)
    }

    private static func predictedIndex(_ snapshot: Snapshot) -> Int {
        predictionLock.lock()
        defer { predictionLock.unlock() }
        return predictions[snapshot.displayId] ?? snapshot.currentIndex
    }

    private static func setPrediction(_ index: Int, for displayId: String) {
        predictionLock.lock()
        predictions[displayId] = index
        predictionLock.unlock()
    }

    private static func post(_ plan: SpaceSwitchPlan) -> Bool {
        (0..<plan.steps).allSatisfy { _ in
            post(.began, plan.direction) && post(.changed, plan.direction) && post(.ended, plan.direction)
        }
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
