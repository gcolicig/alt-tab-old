import Cocoa

/// Story 13: Copy Debug Info, Copy Accessibility Tree, Reset Permissions.
enum DebugTools {
    // MARK: D1

    static func copyDebugInfo() {
        DispatchQueue.global(qos: .userInitiated).async {
            let report = header() + "\n" + DebugProfile.make()
            DispatchQueue.main.async {
                copy(report)
                TransientNotice.show(NSLocalizedString("Debug info copied.", comment: ""))
            }
        }
    }

    private static func header() -> String {
        let build = Bundle.main.object(forInfoDictionaryKey: "GitCommit") as? String ?? "unknown"
        return "AltTab+ debug info — \(ISO8601DateFormatter().string(from: Date())) — version \(App.version) — build \(build)"
    }

    /// Additions to the shared debug profile; read on main because they touch UI-owned state.
    static func extraProfileEntries() -> [(String, String)] {
        Thread.isMainThread ? profileEntriesOnMain() : DispatchQueue.main.sync { profileEntriesOnMain() }
    }

    private static func profileEntriesOnMain() -> [(String, String)] {
        [
            ("Permissions", "accessibility:\(AccessibilityPermission.status) screenRecording:\(ScreenRecordingPermission.status)"),
            ("Signature", signingAuthority()),
            ("Safe mode", String(Preferences.inputModulesSafeMode)),
            ("Active input modules", activeModules()),
            ("Pointer ownership", PointerCategory.allCases.map { "\($0):\(PointerOwnership.state($0))" }.joined(separator: DebugProfile.interSeparator)),
            ("Keep Awake", "\(KeepAwake.state)"),
            ("Typing mute", TypingMute.debugSummary()),
            ("Uptime", String(format: "%.0f s", Date().timeIntervalSince(launchDate))),
        ]
    }

    static let launchDate = Date()

    private static func activeModules() -> String {
        let modules: [(String, Bool)] = [
            ("hyperkey", Preferences.hyperKeyEnabled),
            ("windowDrag", WindowDragEvents.isEnabled),
            ("scrollTap", ScrollwheelEvents.isTapEnabled),
            ("trackpadGesture", Preferences.nextWindowGesture != .disabled),
            ("flickRing", FlickRingEvents.isEnabled),
            ("leader", LeaderController.isEnabled),
            ("catMode", CatMode.isOn),
        ]
        let active = modules.filter(\.1).map(\.0)
        return active.isEmpty ? "none" : active.joined(separator: DebugProfile.interSeparator)
    }

    private static func signingAuthority() -> String {
        var code: SecStaticCode?
        guard SecStaticCodeCreateWithPath(Bundle.main.bundleURL as CFURL, [], &code) == errSecSuccess, let code else { return "unknown" }
        var info: CFDictionary?
        guard SecCodeCopySigningInformation(code, SecCSFlags(rawValue: kSecCSSigningInformation), &info) == errSecSuccess,
              let dictionary = info as? [String: Any] else { return "unknown" }
        guard let certificates = dictionary[kSecCodeInfoCertificates as String] as? [SecCertificate], let leaf = certificates.first else { return "adhoc" }
        return (SecCertificateCopySubjectSummary(leaf) as String?) ?? "unknown"
    }

    // MARK: D2

    static func copyAccessibilityTree() {
        guard AccessibilityPermission.status == .granted else {
            return TransientNotice.show(NSLocalizedString("Accessibility permission is missing.", comment: ""))
        }
        guard let app = NSWorkspace.shared.frontmostApplication, app.processIdentifier != ProcessInfo.processInfo.processIdentifier else {
            return TransientNotice.show(NSLocalizedString("No other app is in front.", comment: ""))
        }
        BackgroundWork.accessibilityCommandsQueue.addOperation { dumpTree(app) }
    }

    private static func dumpTree(_ app: NSRunningApplication) {
        let element = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(element, 0.25)
        guard let window = copyElement(element, kAXFocusedWindowAttribute) else {
            return DispatchQueue.main.async { TransientNotice.show(NSLocalizedString("The app in front has no focused window.", comment: "")) }
        }
        let text = treeHeader(app, window) + "\n" + AccessibilityTreeFormat.render(AXNode(window))
        DispatchQueue.main.async {
            copy(text)
            TransientNotice.show(String(format: NSLocalizedString("Accessibility tree of %@ copied.", comment: ""), app.localizedName ?? "?"))
        }
    }

    private static func treeHeader(_ app: NSRunningApplication, _ window: AXUIElement) -> String {
        let version = app.bundleURL.flatMap { Bundle(url: $0)?.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String } ?? "?"
        let windowId = (try? window.cgWindowId()).map(String.init) ?? "?"
        let frame = AXNode(window).frame.map { "\($0)" } ?? "?"
        return "App: \(app.localizedName ?? "?") (\(app.bundleIdentifier ?? "?") \(version)) pid:\(app.processIdentifier) window:\(windowId) frame:\(frame) space:\(Spaces.currentSpaceIndex)"
    }

    static func copyElement(_ element: AXUIElement, _ attribute: String) -> AXUIElement? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success, let value,
              CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return (value as! AXUIElement)
    }

    // MARK: D3

    static func resetPermissions() {
        guard let bundleId = Bundle.main.bundleIdentifier, confirmReset() else { return }
        for arguments in PermissionResetCommand.arguments(bundleId: bundleId) {
            let (status, output) = run(PermissionResetCommand.tccutil, arguments)
            guard status == 0 else { return showResetFailure(output) }
        }
        App.restart()
    }

    private static func confirmReset() -> Bool {
        let alert = NSAlert()
        alert.messageText = NSLocalizedString("Reset AltTab+ permissions?", comment: "")
        alert.informativeText = NSLocalizedString("Accessibility and Screen Recording are reset for AltTab+ only, then AltTab+ restarts and asks for them again. Use this when the permissions stopped matching the app, for example after a change of its signature.", comment: "")
        alert.addButton(withTitle: NSLocalizedString("Cancel", comment: ""))
        alert.addButton(withTitle: NSLocalizedString("Reset and Restart", comment: ""))
        NSApp.activate(ignoringOtherApps: true)
        return alert.runModal() == .alertSecondButtonReturn
    }

    private static func showResetFailure(_ output: String) {
        let alert = NSAlert()
        alert.messageText = NSLocalizedString("The permissions could not be reset.", comment: "")
        alert.informativeText = output
        alert.runModal()
    }

    private static func run(_ path: String, _ arguments: [String]) -> (Int32, String) {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        process.standardOutput = pipe
        process.standardError = pipe
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return (-1, error.localizedDescription)
        }
        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return (process.terminationStatus, output)
    }

    private static func copy(_ string: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
    }
}

/// Reads an element lazily; values are never read (DB-03), secure fields only by role.
private struct AXNode: AccessibilityNode {
    let element: AXUIElement
    private static let settableCandidates = [kAXPositionAttribute, kAXSizeAttribute, kAXMinimizedAttribute, kAXFullscreenAttribute]

    init(_ element: AXUIElement) {
        self.element = element
    }

    var role: String? { string(kAXRoleAttribute) }
    var subrole: String? { string(kAXSubroleAttribute) }
    var roleDescription: String? { string(kAXRoleDescriptionAttribute) }
    var title: String? { role == "AXSecureTextField" ? nil : string(kAXTitleAttribute) }
    var identifier: String? { string(kAXIdentifierAttribute) }
    var isEnabled: Bool? { copy(kAXEnabledAttribute) as? Bool }
    var isFocused: Bool? { copy(kAXFocusedAttribute) as? Bool }

    var frame: CGRect? {
        guard let position = axValue(kAXPositionAttribute), let size = axValue(kAXSizeAttribute) else { return nil }
        var point = CGPoint.zero
        var extent = CGSize.zero
        guard AXValueGetValue(position, .cgPoint, &point), AXValueGetValue(size, .cgSize, &extent) else { return nil }
        return CGRect(origin: point, size: extent)
    }

    var settableAttributes: [String] {
        Self.settableCandidates.filter { (try? element.isAttributeSettable($0)) == true }.map { $0.replacingOccurrences(of: "AX", with: "") }
    }

    var children: [AccessibilityNode] {
        (copy(kAXChildrenAttribute) as? [AXUIElement] ?? []).map(AXNode.init)
    }

    private func copy(_ attribute: String) -> CFTypeRef? {
        var value: CFTypeRef?
        return AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success ? value : nil
    }

    private func string(_ attribute: String) -> String? {
        copy(attribute) as? String
    }

    private func axValue(_ attribute: String) -> AXValue? {
        guard let value = copy(attribute), CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        return (value as! AXValue)
    }
}
