import Cocoa
import NaturalLanguage
import ScreenCaptureKit
import Translation
import Vision

/// Story 14I. Everything stays in memory and on this Mac: no files, no network.
enum ScreenTools {
    static func captureAvailability() -> ActionAvailability {
        guard #available(macOS 14.0, *) else {
            return .unavailable(NSLocalizedString("Requires macOS 14 or later.", comment: ""))
        }
        guard ScreenRecordingPermission.status == .granted else {
            return .unavailable(NSLocalizedString("Screen Recording permission is missing.", comment: ""))
        }
        return .available
    }

    /// The initializer used below exists only in the macOS 26 SDK (Swift 6.2 toolchains); CI still builds
    /// with Xcode 16, where the action is compiled out and reported as unavailable.
    static func translateAvailability() -> ActionAvailability {
        #if compiler(>=6.2)
        guard #available(macOS 26.0, *) else {
            return .unavailable(NSLocalizedString("Requires macOS 26 or later.", comment: ""))
        }
        return captureAvailability()
        #else
        return .unavailable(NSLocalizedString("This build does not include translation.", comment: ""))
        #endif
    }

    static func clipboardImageAvailability() -> ActionAvailability {
        clipboardImage() == nil ? .unavailable(NSLocalizedString("The clipboard holds no image.", comment: "")) : .available
    }

    // MARK: color

    static func pickColor() {
        NSColorSampler().show { color in
            guard let rgb = color?.usingColorSpace(.sRGB) else { return }
            let hex = ScreenToolsFormat.hex(red: rgb.redComponent, green: rgb.greenComponent, blue: rgb.blueComponent)
            copy(hex)
            TransientNotice.show(String(format: NSLocalizedString("Color %@ copied.", comment: ""), hex))
        }
    }

    // MARK: capture

    static func captureText() {
        captureRegion { image in recognizeText(image) { copyRecognized($0) } }
    }

    static func captureTranslate() {
        captureRegion { image in recognizeText(image) { translate($0) } }
    }

    static func scanQr() {
        captureRegion(scanCodes)
    }

    static func scanQrFromClipboard() {
        guard let image = clipboardImage() else { return NSSound.beep() }
        scanCodes(image)
    }

    private static func captureRegion(_ handler: @escaping (CGImage) -> Void) {
        guard captureAvailability().isAvailable else { return NSSound.beep() }
        RegionSelection.run { rect, screen in
            guard let rect, let screen else { return }
            guard #available(macOS 14.0, *) else { return }
            Task { await capture(rect, screen, handler) }
        }
    }

    @available(macOS 14.0, *)
    private static func capture(_ rect: CGRect, _ screen: NSScreen, _ handler: @escaping (CGImage) -> Void) async {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            guard let displayId = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID,
                  let display = content.displays.first(where: { $0.displayID == displayId }) else { return }
            let image = try await SCScreenshotManager.captureImage(contentFilter: SCContentFilter(display: display, excludingWindows: []),
                configuration: configuration(rect, screen))
            await MainActor.run { handler(image) }
        } catch {
            Logger.error { "Screen capture failed: \(error)" }
            await MainActor.run { TransientNotice.show(NSLocalizedString("The screen area could not be captured.", comment: "")) }
        }
    }

    /// `sourceRect` is in the display's points with the origin at its top left.
    @available(macOS 14.0, *)
    private static func configuration(_ rect: CGRect, _ screen: NSScreen) -> SCStreamConfiguration {
        let local = CGRect(x: rect.minX - screen.frame.minX, y: screen.frame.maxY - rect.maxY, width: rect.width, height: rect.height)
        let configuration = SCStreamConfiguration()
        configuration.sourceRect = local
        configuration.width = Int(local.width * screen.backingScaleFactor)
        configuration.height = Int(local.height * screen.backingScaleFactor)
        configuration.showsCursor = false
        return configuration
    }

    // MARK: text

    private static func recognizeText(_ image: CGImage, _ completion: @escaping (String) -> Void) {
        let request = VNRecognizeTextRequest { request, _ in
            let lines = (request.results as? [VNRecognizedTextObservation] ?? []).compactMap { $0.topCandidates(1).first?.string }
            DispatchQueue.main.async { completion(ScreenToolsFormat.joinLines(lines)) }
        }
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.automaticallyDetectsLanguage = true
        perform(request, on: image)
    }

    private static func copyRecognized(_ text: String) {
        guard !text.isEmpty else { return TransientNotice.show(NSLocalizedString("No text was found.", comment: "")) }
        copy(text)
        TransientNotice.show(NSLocalizedString("Text copied.", comment: ""))
    }

    private static func translate(_ text: String) {
        guard !text.isEmpty else { return TransientNotice.show(NSLocalizedString("No text was found.", comment: "")) }
        #if compiler(>=6.2)
        guard #available(macOS 26.0, *) else { return }
        guard let source = NLLanguageRecognizer.dominantLanguage(for: text).map({ Locale.Language(identifier: $0.rawValue) }) else {
            return TransientNotice.show(NSLocalizedString("The language of the text could not be detected.", comment: ""))
        }
        Task { await translate(text, from: source) }
        #endif
    }

    #if compiler(>=6.2)
    @available(macOS 26.0, *)
    private static func translate(_ text: String, from source: Locale.Language) async {
        do {
            let session = TranslationSession(installedSource: source, target: Locale.current.language)
            let response = try await session.translate(text)
            await MainActor.run { TranslationPanel.show(original: text, translation: response.targetText) }
        } catch {
            Logger.warning { "Translation failed: \(error)" }
            await MainActor.run { offerLanguageDownload() }
        }
    }
    #endif

    private static func offerLanguageDownload() {
        let alert = NSAlert()
        alert.messageText = NSLocalizedString("The text could not be translated.", comment: "")
        alert.informativeText = NSLocalizedString("The translation languages may not be installed on this Mac. You can download them in System Settings.", comment: "")
        alert.addButton(withTitle: NSLocalizedString("Open System Settings", comment: ""))
        alert.addButton(withTitle: NSLocalizedString("Cancel", comment: ""))
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn,
              let url = URL(string: "x-apple.systempreferences:com.apple.Localization-Settings.extension") else { return }
        NSWorkspace.shared.open(url)
    }

    // MARK: codes

    private static func scanCodes(_ image: CGImage) {
        let request = VNDetectBarcodesRequest { request, _ in
            let payloads = (request.results as? [VNBarcodeObservation] ?? []).compactMap(\.payloadStringValue)
            DispatchQueue.main.async { handleCodes(payloads) }
        }
        perform(request, on: image)
    }

    private static func handleCodes(_ payloads: [String]) {
        guard let payload = payloads.first else { return TransientNotice.show(NSLocalizedString("No code was found.", comment: "")) }
        copy(payload)
        guard let url = ScreenToolsFormat.openableUrl(payload) else {
            return TransientNotice.show(NSLocalizedString("Code content copied.", comment: ""))
        }
        offerToOpen(url)
    }

    private static func offerToOpen(_ url: URL) {
        let alert = NSAlert()
        alert.messageText = NSLocalizedString("The code contains a link. It was copied.", comment: "")
        alert.informativeText = url.absoluteString
        alert.addButton(withTitle: NSLocalizedString("Close", comment: ""))
        alert.addButton(withTitle: NSLocalizedString("Open", comment: ""))
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertSecondButtonReturn else { return }
        NSWorkspace.shared.open(url)
    }

    // MARK: helpers

    private static func perform(_ request: VNRequest, on image: CGImage) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try VNImageRequestHandler(cgImage: image).perform([request])
            } catch {
                Logger.error { "Vision request failed: \(error)" }
            }
        }
    }

    private static func clipboardImage() -> CGImage? {
        guard let image = NSImage(pasteboard: NSPasteboard.general) else { return nil }
        return image.cgImage(forProposedRect: nil, context: nil, hints: nil)
    }

    private static func copy(_ string: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
    }
}

/// Original and translation side by side, with a copy button; closes like any window.
enum TranslationPanel {
    private static var window: NSPanel?

    static func show(original: String, translation: String) {
        window?.close()
        let panel = NSPanel(contentRect: CGRect(x: 0, y: 0, width: 640, height: 320), styleMask: [.titled, .closable, .resizable, .utilityWindow], backing: .buffered, defer: false)
        panel.title = NSLocalizedString("Translation", comment: "")
        panel.isReleasedWhenClosed = false
        panel.contentView = content(original, translation)
        panel.center()
        window = panel
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    private static func content(_ original: String, _ translation: String) -> NSView {
        let copyButton = NSButton(title: NSLocalizedString("Copy Translation", comment: ""), target: nil, action: nil)
        copyButton.onAction = { _ in
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(translation, forType: .string)
        }
        let columns = NSStackView(views: [textColumn(original), textColumn(translation)])
        columns.distribution = .fillEqually
        let stack = NSStackView(views: [columns, copyButton])
        stack.orientation = .vertical
        stack.edgeInsets = NSEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        return stack
    }

    private static func textColumn(_ text: String) -> NSView {
        let scroll = NSTextView.scrollableTextView()
        (scroll.documentView as? NSTextView)?.string = text
        (scroll.documentView as? NSTextView)?.isEditable = false
        return scroll
    }
}
