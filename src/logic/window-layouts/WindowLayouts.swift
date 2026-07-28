import Cocoa

class WindowLayouts {
    private static var restoreFrames = [AXUIElement: CGRect]()
    private static let frameTolerance = CGFloat(2)
    private static let operationQueue = LabeledOperationQueue("windowLayouts", .userInteractive, 1)

    static func perform(_ action: WindowLayoutAction) {
        guard !App.appIsBeingUsed, !Preferences.inputModulesSafeMode else { return }
        DispatchQueue.main.async {
            guard let runningApplication = NSWorkspace.shared.frontmostApplication,
                  runningApplication.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return }
            let screenFrames = quartzVisibleFrames()
            operationQueue.addOperation {
                apply(action, to: runningApplication.processIdentifier, screenFrames: screenFrames)
            }
        }
    }

    static func perform(_ action: DisplayMoveAction) {
        guard !App.appIsBeingUsed, !Preferences.inputModulesSafeMode else { return }
        DispatchQueue.main.async {
            guard let runningApplication = NSWorkspace.shared.frontmostApplication,
                  runningApplication.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return }
            let screenFrames = quartzVisibleFrames()
            operationQueue.addOperation {
                apply(action, to: runningApplication.processIdentifier, screenFrames: screenFrames)
            }
        }
    }

    private static func apply(_ action: DisplayMoveAction, to pid: pid_t, screenFrames: [CGRect]) {
        do {
            let window = try focusedWindow(pid)
            let attributes = try eligibleAttributes(window)
            let currentFrame = CGRect(origin: attributes.position!, size: attributes.size!)
            let ordered = DisplayMoveGeometry.orderedFrames(screenFrames)
            guard let sourceFrame = bestScreenFrame(for: currentFrame, ordered),
                  let currentIndex = ordered.firstIndex(of: sourceFrame),
                  let targetIndex = DisplayMoveGeometry.targetScreenIndex(action, currentIndex: currentIndex, screenCount: ordered.count),
                  let targetFrame = DisplayMoveGeometry.frame(currentFrame, from: sourceFrame, to: ordered[targetIndex]) else { return }
            // a display move is not a layout, so it does not become the frame that Restore returns to
            try window.setFrame(targetFrame)
            Logger.debug { "Display move \(action.rawValue) pid:\(pid) proposed:\(targetFrame)" }
        } catch {
            Logger.error { "Display move \(action.rawValue) failed for pid \(pid): \(error)" }
        }
    }

    private static func apply(_ action: WindowLayoutAction, to pid: pid_t, screenFrames: [CGRect]) {
        do {
            let window = try focusedWindow(pid)
            let attributes = try eligibleAttributes(window)
            let currentFrame = CGRect(origin: attributes.position!, size: attributes.size!)
            if action == .restore {
                guard let restoreFrame = restoreFrames[window] else { return }
                try setAndVerify(restoreFrame, on: window, pid: pid, action: action)
                restoreFrames.removeValue(forKey: window)
                return
            }
            guard let screenFrame = bestScreenFrame(for: currentFrame, screenFrames),
                  let targetFrame = WindowLayoutGeometry.frame(action, in: screenFrame) else { return }
            if restoreFrames[window] == nil {
                restoreFrames[window] = currentFrame
            }
            try setAndVerify(targetFrame, on: window, pid: pid, action: action)
        } catch {
            Logger.error { "Window layout \(action.rawValue) failed for pid \(pid): \(error)" }
        }
    }

    private static func focusedWindow(_ pid: pid_t) throws -> AXUIElement {
        let application = AXUIElementCreateApplication(pid)
        guard let window = try application.attributes([kAXFocusedWindowAttribute]).focusedWindow else { throw AxError.runtimeError }
        return window
    }

    private static func eligibleAttributes(_ window: AXUIElement) throws -> AXAttributes {
        let keys = [kAXRoleAttribute, kAXSubroleAttribute, kAXPositionAttribute, kAXSizeAttribute, kAXFullscreenAttribute, kAXMinimizedAttribute]
        let attributes = try window.attributes(keys)
        guard attributes.role == kAXWindowRole,
              [kAXStandardWindowSubrole, kAXDialogSubrole].contains(attributes.subrole),
              attributes.isFullscreen != true,
              attributes.isMinimized != true,
              attributes.position != nil,
              attributes.size != nil,
              try window.isAttributeSettable(kAXPositionAttribute),
              try window.isAttributeSettable(kAXSizeAttribute) else { throw AxError.runtimeError }
        return attributes
    }

    private static func setAndVerify(_ frame: CGRect, on window: AXUIElement, pid: pid_t, action: WindowLayoutAction) throws {
        try window.setFrame(frame)
        let result = try window.attributes([kAXPositionAttribute, kAXSizeAttribute])
        guard let position = result.position, let size = result.size else { throw AxError.runtimeError }
        let actual = CGRect(origin: position, size: size)
        let matches = abs(actual.minX - frame.minX) <= frameTolerance &&
            abs(actual.minY - frame.minY) <= frameTolerance &&
            abs(actual.width - frame.width) <= frameTolerance &&
            abs(actual.height - frame.height) <= frameTolerance
        if matches {
            Logger.debug { "Window layout \(action.rawValue) pid:\(pid) proposed:\(frame) result:\(actual)" }
        } else {
            Logger.warning { "Window layout \(action.rawValue) pid:\(pid) proposed:\(frame) result:\(actual)" }
        }
    }

    private static func bestScreenFrame(for windowFrame: CGRect, _ screenFrames: [CGRect]) -> CGRect? {
        screenFrames.max {
            intersectionArea(windowFrame, $0) < intersectionArea(windowFrame, $1)
        }
    }

    private static func intersectionArea(_ lhs: CGRect, _ rhs: CGRect) -> CGFloat {
        let intersection = lhs.intersection(rhs)
        return intersection.isNull ? 0 : intersection.width * intersection.height
    }

    private static func quartzVisibleFrames() -> [CGRect] {
        guard let primaryFrame = NSScreen.screens.first?.frame else { return [] }
        return NSScreen.screens.map {
            let visibleFrame = $0.visibleFrame
            return CGRect(x: visibleFrame.minX,
                          y: primaryFrame.maxY - visibleFrame.maxY,
                          width: visibleFrame.width,
                          height: visibleFrame.height)
        }
    }
}
