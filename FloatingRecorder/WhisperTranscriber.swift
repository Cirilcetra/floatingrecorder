import Foundation
import CoreGraphics
import AppKit
import ApplicationServices

final class WhisperTranscriber: ObservableObject {
    @Published var isTranscribing = false

    private let modelManager: ModelManager
    private let whisperPath: String

    init(modelManager: ModelManager) {
        self.modelManager = modelManager

        let bundle = Bundle.main
        self.whisperPath = bundle.path(forResource: "whisper", ofType: nil, inDirectory: "whisper") ?? ""

        if whisperPath.isEmpty || !FileManager.default.fileExists(atPath: whisperPath) {
            Log.whisper.error("Whisper executable not found at: \(self.whisperPath)")
        } else if !FileManager.default.isExecutableFile(atPath: whisperPath) {
            try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: whisperPath)
        }
    }

    func transcribeAudio(at url: URL) async throws -> String {
        guard !whisperPath.isEmpty, FileManager.default.fileExists(atPath: whisperPath) else {
            throw NSError(domain: "WhisperTranscriber", code: 1, userInfo: [NSLocalizedDescriptionKey: "Whisper binary not found."])
        }

        guard let model = modelManager.activeModel else {
            throw NSError(domain: "WhisperTranscriber", code: 2, userInfo: [NSLocalizedDescriptionKey: "No model installed. Download one in Preferences → Models."])
        }
        let modelURL = modelManager.localURL(for: model)
        guard FileManager.default.fileExists(atPath: modelURL.path) else {
            throw NSError(domain: "WhisperTranscriber", code: 2, userInfo: [NSLocalizedDescriptionKey: "Active model is missing on disk."])
        }

        await MainActor.run { isTranscribing = true }
        defer {
            Task { @MainActor in self.isTranscribing = false }
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: whisperPath)
        process.arguments = [
            "-m", modelURL.path,
            "-f", url.path,
            "-nt",
            "--output-txt"
        ]

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        let collectedOut = DataBox()
        let collectedErr = DataBox()

        stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            collectedOut.append(data)
        }
        stderrPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            collectedErr.append(data)
        }

        try process.run()
        process.waitUntilExit()

        stdoutPipe.fileHandleForReading.readabilityHandler = nil
        stderrPipe.fileHandleForReading.readabilityHandler = nil

        if process.terminationStatus != 0 {
            let errString = String(data: collectedErr.snapshot, encoding: .utf8) ?? ""
            var detail = errString
            if errString.contains("Library not loaded") || errString.contains("dyld") {
                detail += "\n\nIf you see “different Team IDs”, rebuild the app with the latest build-and-dmg.sh (whisper CLI needs its own entitlements). Otherwise missing .dylibs: run scripts/bundle-whisper-dylibs.sh then rebuild the DMG (see README)."
            }
            Log.whisper.error("Whisper exit \(process.terminationStatus): \(errString)")
            throw NSError(
                domain: "WhisperTranscriber",
                code: 3,
                userInfo: [NSLocalizedDescriptionKey: "Whisper failed (\(process.terminationStatus)): \(detail)"]
            )
        }

        let outputFile = url.appendingPathExtension("txt")
        guard FileManager.default.fileExists(atPath: outputFile.path) else {
            throw NSError(domain: "WhisperTranscriber", code: 4, userInfo: [NSLocalizedDescriptionKey: "Transcription output missing."])
        }

        let transcription = try String(contentsOf: outputFile, encoding: .utf8)
        try? FileManager.default.removeItem(at: outputFile)

        return transcription.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Smart paste

    /// Returns true iff Accessibility reports a focused text-input UI in the previously-active app.
    func focusedElementAcceptsText(in app: NSRunningApplication?) -> Bool {
        guard let app else { return false }

        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        var focused: AnyObject?
        let result = AXUIElementCopyAttributeValue(axApp, kAXFocusedUIElementAttribute as CFString, &focused)
        guard result == .success, let element = focused else { return false }

        var roleValue: AnyObject?
        AXUIElementCopyAttributeValue(element as! AXUIElement, kAXRoleAttribute as CFString, &roleValue)
        let role = roleValue as? String ?? ""

        let acceptingRoles: Set<String> = [
            "AXTextField", "AXTextArea", "AXComboBox", "AXSearchField"
        ]
        if acceptingRoles.contains(role) { return true }

        var settable: AnyObject?
        AXUIElementCopyAttributeValue(element as! AXUIElement, kAXValueAttribute as CFString, &settable)
        if settable is String { return true }

        return false
    }

    /// Copy to clipboard, optionally synthesize Cmd+V into the previously-active app.
    /// - Returns: `.pasted` if we pasted into a focused text field, `.clipboardOnly` otherwise.
    @discardableResult
    func deliverText(_ text: String, previousApp: NSRunningApplication?, autoPasteEnabled: Bool) -> PasteOutcome {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        guard autoPasteEnabled else { return .clipboardOnly }

        guard let app = previousApp else { return .clipboardOnly }
        if #available(macOS 14.0, *) {
            app.activate()
        } else {
            app.activate(options: [.activateIgnoringOtherApps])
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
            guard let self else { return }
            if self.focusedElementAcceptsText(in: app) {
                Self.synthesizeCmdV()
            } else {
                Log.paste.info("Focused element does not accept text; left in clipboard only")
            }
        }
        return .clipboardOnly
    }

    private static func synthesizeCmdV() {
        let source = CGEventSource(stateID: .hidSystemState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)
        let keyUp   = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
        keyDown?.flags = .maskCommand
        keyUp?.flags   = .maskCommand
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }

    enum PasteOutcome {
        case pasted
        case clipboardOnly
    }
}

private final class DataBox: @unchecked Sendable {
    private let lock = NSLock()
    private var data = Data()

    func append(_ chunk: Data) {
        lock.lock()
        data.append(chunk)
        lock.unlock()
    }

    var snapshot: Data {
        lock.lock()
        defer { lock.unlock() }
        return data
    }
}

