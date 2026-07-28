import Cocoa

/// Temporary instrumentation for the Instant Spaces spike (S-06). It answers what the system actually
/// does with a synthetic swipe: whether it is accepted, how long the switch takes, and what
/// `CGSManagedDisplayGetCurrentSpace` reports while it happens. Remove together with the spike.
enum SpacesTrace {
    private static let fileUrl = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Logs/alt-tab-plus-spaces-trace.log")
    private static let maximumFileSize = 4 * 1024 * 1024
    private static let samplingInterval = TimeInterval(0.025)
    private static let samplingDuration = TimeInterval(3)
    private static let queue = DispatchQueue(label: "com.gcolicig.alttab-plus.spaces-trace")
    private static var sequenceStartedAt = ProcessInfo.processInfo.systemUptime
    private static var samplingSequence = UInt64(0)
    private static var lastSampledSpaceId = CGSSpaceID(0)
    private static var activationObserversInstalled = false

    static func beginSequence(_ description: String, displayId: String, spaceIds: [CGSSpaceID], generation: UInt64) {
        installActivationObservers()
        sequenceStartedAt = ProcessInfo.processInfo.systemUptime
        write("")
        write("=== \(description) | display \(displayId) | generation \(generation)")
        write("    spaces: \(spaceIds.map(String.init).joined(separator: ", "))")
        startSampling(displayId, generation)
    }

    static func event(_ message: @autoclosure () -> String) {
        write("  \(elapsedMilliseconds())ms \(message())")
    }

    /// macOS pulls the screen to the Space holding a window of the app that just became active. If that
    /// is what undoes a switch, the trace shows the activation right before the Space changes back.
    private static func installActivationObservers() {
        guard !activationObserversInstalled else { return }
        activationObserversInstalled = true
        [NSApplication.didBecomeActiveNotification, NSApplication.didResignActiveNotification].forEach { name in
            NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { _ in
                let windows = NSApp.windows.filter { $0.isVisible }.map { "\(type(of: $0))" }
                event("app \(name == NSApplication.didBecomeActiveNotification ? "became active" : "resigned active"), visible windows: \(windows.isEmpty ? "none" : windows.joined(separator: ", "))")
            }
        }
    }

    /// Samples the reported Space far more often than the switching logic does, so the trace shows when
    /// a swipe took effect rather than only when the logic happened to look.
    private static func startSampling(_ displayId: String, _ generation: UInt64) {
        samplingSequence = generation
        lastSampledSpaceId = 0
        let deadline = ProcessInfo.processInfo.systemUptime + samplingDuration
        func sample() {
            guard samplingSequence == generation, ProcessInfo.processInfo.systemUptime < deadline else { return }
            if let spaceId = InstantSpacesPrivateApi.currentSpaceId(displayId as CFString), spaceId != lastSampledSpaceId {
                lastSampledSpaceId = spaceId
                write("  \(elapsedMilliseconds())ms sampled space id \(spaceId)")
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + samplingInterval) { sample() }
        }
        sample()
    }

    static func stopSampling() {
        samplingSequence = 0
    }

    private static func elapsedMilliseconds() -> Int {
        Int((ProcessInfo.processInfo.systemUptime - sequenceStartedAt) * 1000)
    }

    private static func write(_ line: String) {
        queue.async {
            guard let data = (line + "\n").data(using: .utf8) else { return }
            let manager = FileManager.default
            if !manager.fileExists(atPath: fileUrl.path) {
                try? manager.createDirectory(at: fileUrl.deletingLastPathComponent(), withIntermediateDirectories: true)
                manager.createFile(atPath: fileUrl.path, contents: header())
            }
            guard let handle = try? FileHandle(forWritingTo: fileUrl) else { return }
            defer { handle.closeFile() }
            guard handle.seekToEndOfFile() < UInt64(maximumFileSize) else { return }
            handle.write(data)
        }
    }

    private static func header() -> Data? {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        let system = ProcessInfo.processInfo.operatingSystemVersionString
        return "AltTab+ \(version) | \(system) | started \(Date())\n".data(using: .utf8)
    }
}
