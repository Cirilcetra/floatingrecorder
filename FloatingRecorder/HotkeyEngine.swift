import Foundation
import AppKit
import Carbon
import ApplicationServices
import CoreGraphics

/// A global hotkey engine that distinguishes between:
///  - TAP: quick press+release of the configured chord → fires `onTap`
///  - HOLD: chord held past `holdThreshold` → fires `onHoldStart`, then `onHoldEnd` on release
///
/// Supports both pure-modifier chords (e.g. ⌥⌘ with no key) and modifier+key chords
/// (e.g. ⌘⇧R). Pure-modifier chords listen to `.flagsChanged` only; chords with a
/// non-modifier key require that key to be pressed while the modifiers are held.
final class HotkeyEngine {
    typealias Callback = () -> Void

    private let chord: HotkeyChord
    private let onTap: Callback
    private let onHoldStart: Callback
    private let onHoldEnd: Callback

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    private var chordActive: Bool = false
    private var didFireHold: Bool = false
    private var holdWorkItem: DispatchWorkItem?

    private let holdThreshold: TimeInterval = 0.25

    init(
        chord: HotkeyChord,
        onTap: @escaping Callback,
        onHoldStart: @escaping Callback,
        onHoldEnd: @escaping Callback
    ) {
        self.chord = chord
        self.onTap = onTap
        self.onHoldStart = onHoldStart
        self.onHoldEnd = onHoldEnd
    }

    deinit { stop() }

    // MARK: - Control

    @discardableResult
    func start() -> Bool {
        stop()

        guard AXIsProcessTrusted() else {
            Log.hotkey.info("Accessibility not granted; hotkey engine not starting")
            return false
        }

        let eventMask: CGEventMask =
            (1 << CGEventType.flagsChanged.rawValue) |
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.keyUp.rawValue)

        let refcon = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: eventMask,
            callback: { _, type, event, userInfo in
                guard let userInfo else { return Unmanaged.passUnretained(event) }
                let engine = Unmanaged<HotkeyEngine>.fromOpaque(userInfo).takeUnretainedValue()
                engine.handleEvent(type: type, event: event)
                return Unmanaged.passUnretained(event)
            },
            userInfo: refcon
        ) else {
            Log.hotkey.error("Failed to create CGEvent tap")
            return false
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        self.eventTap = tap
        self.runLoopSource = source
        Log.hotkey.info("Hotkey engine started for \(self.chord.displayString)")
        return true
    }

    func stop() {
        holdWorkItem?.cancel()
        holdWorkItem = nil
        chordActive = false
        didFireHold = false

        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        runLoopSource = nil
        eventTap = nil
    }

    // MARK: - Event handling

    private func handleEvent(type: CGEventType, event: CGEvent) {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return
        }

        let flags = event.flags

        // Require EXACT modifier match (ignore caps lock, numeric, secondary fn).
        let wantedModifiers = chord.nsModifierFlags
        let currentModifiers = Self.nsModifierFlags(from: flags)
        let modifiersMatch = (currentModifiers == wantedModifiers)

        if let requiredKeyCode = chord.keyCode {
            // Modifier + key chord: fire on keyDown while modifiers match.
            if type == .keyDown {
                let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
                if keyCode == requiredKeyCode && modifiersMatch {
                    handleChordEngaged()
                }
            } else if type == .keyUp {
                let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
                if keyCode == requiredKeyCode {
                    handleChordReleased()
                }
            } else if type == .flagsChanged && chordActive && !modifiersMatch {
                // Modifiers released while key still "logically" down — treat as release.
                handleChordReleased()
            }
        } else {
            // Pure-modifier chord: track via flagsChanged only.
            if type == .flagsChanged {
                if !chordActive && modifiersMatch {
                    handleChordEngaged()
                } else if chordActive && !modifiersMatch {
                    handleChordReleased()
                }
            } else if type == .keyDown && chordActive {
                // User pressed an actual key while holding the chord → treat as a real
                // shortcut to some app, cancel our own handling.
                cancelChord()
            }
        }
    }

    private func handleChordEngaged() {
        guard !chordActive else { return }
        chordActive = true
        didFireHold = false

        let work = DispatchWorkItem { [weak self] in
            guard let self, self.chordActive else { return }
            self.didFireHold = true
            self.onHoldStart()
        }
        holdWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + holdThreshold, execute: work)
    }

    private func handleChordReleased() {
        guard chordActive else { return }
        chordActive = false

        holdWorkItem?.cancel()
        holdWorkItem = nil

        if didFireHold {
            onHoldEnd()
        } else {
            onTap()
        }
        didFireHold = false
    }

    private func cancelChord() {
        holdWorkItem?.cancel()
        holdWorkItem = nil
        chordActive = false
        didFireHold = false
    }

    // MARK: - Helpers

    private static func nsModifierFlags(from cgFlags: CGEventFlags) -> NSEvent.ModifierFlags {
        var flags: NSEvent.ModifierFlags = []
        if cgFlags.contains(.maskCommand)   { flags.insert(.command) }
        if cgFlags.contains(.maskAlternate) { flags.insert(.option) }
        if cgFlags.contains(.maskControl)   { flags.insert(.control) }
        if cgFlags.contains(.maskShift)     { flags.insert(.shift) }
        return flags
    }
}

// MARK: - Accessibility helpers

enum AccessibilityPermission {
    private static let promptThrottleLock = NSLock()
    private static var lastPromptWallTime: TimeInterval = 0
    /// Avoid stacking the system “Accessibility” dialog when onboarding + Preferences both call in.
    private static let promptMinInterval: TimeInterval = 120

    /// Unprompted trust check. macOS caches this result **per-process**; a newly-granted
    /// permission will NOT flip this to true until the app is relaunched.
    static var isTrusted: Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    /// Shows the system prompt asking the user to open Settings.
    /// Returns the current trust value (usually false, because the user hasn't granted yet).
    @discardableResult
    static func requestPrompt() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    /// Same as `requestPrompt()` but at most once per `promptMinInterval` while still untrusted.
    @discardableResult
    static func requestPromptThrottled() -> Bool {
        guard !isTrusted else { return true }
        promptThrottleLock.lock()
        defer { promptThrottleLock.unlock() }
        let now = Date().timeIntervalSince1970
        if now - lastPromptWallTime < promptMinInterval {
            Log.hotkey.notice("Skipping Accessibility prompt (throttled)")
            return false
        }
        lastPromptWallTime = now
        return requestPrompt()
    }

    /// Open System Settings → Privacy & Security → Accessibility.
    static func openSettings() {
        // macOS 13+ uses the "PrivacySecurity.extension" URL; older systems use the legacy one.
        let urls = [
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility",
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        ]
        for raw in urls {
            if let url = URL(string: raw), NSWorkspace.shared.open(url) { return }
        }
    }

    /// Relaunch the app so macOS refreshes the Accessibility trust cache.
    /// Never use `open -n` here — it spawns an extra process while the old one is still alive.
    static func relaunchApp() {
        guard let bundleId = Bundle.main.bundleIdentifier else {
            Log.hotkey.error("relaunchApp: missing CFBundleIdentifier")
            NSApp.terminate(nil)
            return
        }

        // Detached shell: after this process quits, `open -b` starts one fresh instance (no `-n`).
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        let escaped = bundleId.replacingOccurrences(of: "'", with: "'\\''")
        task.arguments = ["-c", "(sleep 0.5; /usr/bin/open -b '\(escaped)') &"]
        do {
            try task.run()
            Log.hotkey.info("Scheduled relaunch via open -b after quit")
        } catch {
            Log.hotkey.error("relaunchApp spawn failed: \(error.localizedDescription)")
        }

        DispatchQueue.main.async {
            NSApp.terminate(nil)
        }
    }
}
