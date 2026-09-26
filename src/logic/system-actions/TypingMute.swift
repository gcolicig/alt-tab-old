import CoreAudio
import Foundation

enum TypingMuteIndicator {
    case none
    case muted
    case paused
}

/// spec-typing-mute.md. Silences the microphones in use while the user types, and gives back only what it
/// silenced itself. The keyboard tap calls `keyActivity`; that path only takes a lock and compares, every
/// CoreAudio call runs on `queue` (TM-03). The decisions live in `TypingMuteStateMachine`.
enum TypingMute {
    static let queue = DispatchQueue(label: "typingMute", qos: .userInteractive)
    private static let markerKey = "typingMuteMarker"
    private static let lock = NSLock()
    // guarded by `lock`: read from the tap thread and, through `owns`, from any thread (TM-10)
    private static var state = TypingMuteStateMachine()
    private static var hold: TimeInterval = 0.4
    private static var isEnabled = false
    private static var ownedIds = Set<AudioObjectID>()
    private static var lastIdleKeyLog: TimeInterval = 0
    /// Set from the menu bar icon; cleared once no app uses a microphone any more, so the next call is covered.
    private static var isPaused = false
    // only touched on `queue`
    private static var plan = [TypingMuteTarget]()
    private static var owned = [AudioObjectID: TypingMuteOwnedDevice]()
    private static var timer: DispatchSourceTimer?
    private static var planIsStale = false
    private static var latencies = TypingMuteLatencies()
    private static var releaseFailures = 0

    // MARK: - main thread

    static func preferenceChanged() {
        let enabled = Preferences.typingMuteEnabled && !Preferences.inputModulesSafeMode
        let holdSeconds = TimeInterval(Preferences.typingMuteHoldMs) / 1000
        withLock { hold = holdSeconds }
        guard enabled != withLock({ isEnabled }) else { return }
        withLock { isEnabled = enabled }
        Logger.debug { "typing mute: enabled:\(enabled) hold:\(holdSeconds)" }
        if !enabled { releaseAll() }
        queue.async { enabled ? TypingMuteAudio.startObserving() : TypingMuteAudio.stopObserving() }
        queue.async { rebuildPlan() }
    }

    /// Panic switch, Safe Mode, quit, turning it off: every device typing silenced is open again on return.
    static func releaseAll() {
        withLock { _ = state.end() }
        queue.sync { release() }
    }

    /// A manual microphone action during a phase: the devices stay silenced but belong to the user now.
    /// Called before the manual write, so nothing typing wrote is ever given back after it.
    static func surrenderOwnership() -> [TypingMuteOwnedDevice] {
        guard withLock({ state.end() }) else { return [] }
        return queue.sync {
            cancelTimer()
            let surrendered = Array(owned.values)
            owned = [:]
            publishOwnership()
            UserDefaults.standard.removeObject(forKey: markerKey)
            Logger.debug { "typing mute: surrendered \(surrendered.count) devices to a manual action" }
            return surrendered
        }
    }

    /// The yellow icon: the microphone opens now and typing stops muting until no app records any more.
    static func pauseUntilMicrophoneIdle() {
        withLock {
            isPaused = true
            _ = state.end()
        }
        Logger.debug { "typing mute: paused until the microphone is idle" }
        queue.sync {
            release()
            rebuildPlan()
        }
        MicMuteIndicator.refresh()
    }

    static func resume() {
        withLock { isPaused = false }
        Logger.debug { "typing mute: resumed" }
        queue.async { rebuildPlan() }
        MicMuteIndicator.refresh()
    }

    static var indicator: TypingMuteIndicator {
        withLock { !ownedIds.isEmpty ? .muted : isPaused ? .paused : .none }
    }

    /// Launch: a marker left behind means AltTab+ died during a phase. Runs whether or not the setting is on.
    static func recoverAfterUncleanExit() {
        guard let marker = UserDefaults.standard.string(forKey: markerKey) else { return }
        UserDefaults.standard.removeObject(forKey: markerKey)
        let devices = TypingMuteOwnership.decodeMarker(marker)
        queue.sync { devices.forEach { TypingMuteAudio.recover($0) } }
        Logger.warning { "typing mute: recovered \(devices.count) devices after an unclean exit" }
    }

    static func debugSummary() -> String {
        let (enabled, armed, holding, paused) = withLock { (isEnabled, state.isArmed, state.isHolding, isPaused) }
        let details = queue.sync { "planned:\(plan.count) owned:\(owned.count) releaseFailures:\(releaseFailures) latency: \(latencies.summary())" }
        return "enabled:\(enabled) armed:\(armed) holding:\(holding) paused:\(paused) \(details)"
    }

    // MARK: - any thread

    static func owns(_ device: AudioObjectID) -> Bool {
        withLock { ownedIds.contains(device) }
    }

    /// Keyboard tap thread. Carries no key code: nothing about what was typed leaves this call (TM-08).
    static func keyActivity(_ key: TypingMuteKey) {
        let now = ProcessInfo.processInfo.systemUptime
        let decision = withLock { state.key(key, at: now, hold: hold) }
        logIdleKeyIfNeeded(key, decision, now)
        guard case .mute(let generation) = decision else { return }
        queue.async { mute(generation, startedAt: now) }
    }

    /// At most every 5 s: a fresh key press that did not start a phase, with the reason in the state.
    private static func logIdleKeyIfNeeded(_ key: TypingMuteKey, _ decision: TypingMuteKeyDecision, _ now: TimeInterval) {
        guard key == .down(isAutorepeat: false), decision == .none else { return }
        let (armed, holding, shouldLog) = withLock { () -> (Bool, Bool, Bool) in
            let shouldLog = now - lastIdleKeyLog > 5
            if shouldLog { lastIdleKeyLog = now }
            return (state.isArmed, state.isHolding, shouldLog)
        }
        guard shouldLog, !holding else { return }
        Logger.debug { "typing mute: key press ignored, armed:\(armed)" }
    }

    // MARK: - queue

    static func rebuildPlan() {
        guard !withLock({ state.isHolding }) else {
            planIsStale = true
            return
        }
        planIsStale = false
        let enabled = withLock { isEnabled }
        let inUse = enabled && TypingMuteAudio.anyInputRunning()
        let paused = updatePause(inUse: inUse)
        plan = inUse && !paused ? TypingMuteAudio.targets().filter(TypingMuteOwnership.canSilence) : []
        withLock { state.isArmed = !plan.isEmpty }
        Logger.debug { "typing mute: plan \(plan.map { "\($0.uid) \($0.route) \($0.currentValue)" }) armed:\(!plan.isEmpty) paused:\(paused)" }
    }

    /// The pause ends with the call it was meant for: once no app records, the next recording is covered again.
    private static func updatePause(inUse: Bool) -> Bool {
        let (paused, ended) = withLock { () -> (Bool, Bool) in
            let ended = isPaused && !inUse
            if ended { isPaused = false }
            return (isPaused, ended)
        }
        if ended {
            Logger.debug { "typing mute: pause ended, no microphone in use" }
            MicMuteIndicator.refresh()
        }
        return paused
    }

    /// A property of a device changed. Our own writes land here too; only a value different from what
    /// typing wrote is somebody else's, and that device leaves the phase untouched (TM-04).
    static func deviceChanged(_ device: AudioObjectID) {
        guard let entry = owned[device] else { return rebuildPlan() }
        let observed = TypingMuteAudio.read(entry)
        if observed.map({ TypingMuteOwnership.isExternalChange(entry, observed: $0) }) ?? true {
            drop(device)
        }
        guard !owned.isEmpty, !owned.keys.contains(where: TypingMuteAudio.isRunningSomewhere) else { return }
        withLock { _ = state.end() }
        release()
    }

    static func devicesChanged(_ present: Set<AudioObjectID>) {
        owned.keys.filter { !present.contains($0) }.forEach(drop)
        rebuildPlan()
    }

    private static func mute(_ generation: UInt64, startedAt: TimeInterval) {
        guard withLock({ state.isCurrent(generation) }) else { return }
        let entries = plan.map(TypingMuteOwnership.own)
        entries.forEach { owned[AudioObjectID($0.device)] = $0 }
        // published before the writes, so no reader ever sees a typing mute as the user's own
        publishOwnership()
        writeMarker()
        entries.forEach { silence($0, startedAt) }
        Logger.debug { "typing mute: phase started, silenced \(owned.count) of \(entries.count)" }
        scheduleTimer()
    }

    private static func silence(_ entry: TypingMuteOwnedDevice, _ startedAt: TimeInterval) {
        guard TypingMuteAudio.write(entry, entry.written) else {
            drop(AudioObjectID(entry.device))
            return
        }
        latencies.record(entry.uid, (ProcessInfo.processInfo.systemUptime - startedAt) * 1000)
    }

    private static func release() {
        cancelTimer()
        let entries = Array(owned.values)
        owned = [:]
        let failed = entries.filter { !TypingMuteAudio.restore($0) }
        if !entries.isEmpty { Logger.debug { "typing mute: phase ended, restored \(entries.count - failed.count) of \(entries.count)" } }
        failed.isEmpty ? UserDefaults.standard.removeObject(forKey: markerKey) : retryRelease(failed)
        publishOwnership()
        if planIsStale || !entries.isEmpty { rebuildPlan() }
    }

    /// One retry after 100 ms. A device that still fails stays in the marker, so the next launch tries again.
    private static func retryRelease(_ failed: [TypingMuteOwnedDevice]) {
        UserDefaults.standard.set(TypingMuteOwnership.encodeMarker(failed), forKey: markerKey)
        queue.asyncAfter(deadline: .now() + .milliseconds(100)) {
            let stillFailing = failed.filter { !TypingMuteAudio.restore($0) }
            releaseFailures += stillFailing.count
            guard stillFailing.isEmpty else {
                UserDefaults.standard.set(TypingMuteOwnership.encodeMarker(stillFailing), forKey: markerKey)
                Logger.error { "typing mute: could not give back \(stillFailing.count) devices" }
                return
            }
            UserDefaults.standard.removeObject(forKey: markerKey)
        }
    }

    private static func drop(_ device: AudioObjectID) {
        guard owned.removeValue(forKey: device) != nil else { return }
        publishOwnership()
        writeMarker()
    }

    private static func writeMarker() {
        guard !owned.isEmpty else { return UserDefaults.standard.removeObject(forKey: markerKey) }
        UserDefaults.standard.set(TypingMuteOwnership.encodeMarker(Array(owned.values)), forKey: markerKey)
    }

    private static func publishOwnership() {
        let ids = Set(owned.keys)
        withLock { ownedIds = ids }
        MicMuteIndicator.refresh()
    }

    private static func scheduleTimer() {
        let deadline = withLock { state.deadline }
        let timer = self.timer ?? makeTimer()
        timer.schedule(deadline: .now() + max(0, deadline - ProcessInfo.processInfo.systemUptime))
    }

    private static func makeTimer() -> DispatchSourceTimer {
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.setEventHandler(handler: timerFired)
        timer.resume()
        self.timer = timer
        return timer
    }

    private static func timerFired() {
        let decision = withLock { state.timerFired(at: ProcessInfo.processInfo.systemUptime) }
        switch decision {
            case .wait: scheduleTimer()
            case .release: release()
            case .stop: cancelTimer()
        }
    }

    /// No timer outside a phase (Q-10).
    private static func cancelTimer() {
        timer?.cancel()
        timer = nil
    }

    private static func withLock<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }
}
