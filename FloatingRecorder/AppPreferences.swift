import Foundation
import SwiftUI
import AppKit
import Combine

// MARK: - Hotkey Chord

struct HotkeyChord: Codable, Equatable, Hashable {
    var modifiers: Modifiers
    var keyCode: UInt16?

    struct Modifiers: OptionSet, Codable, Hashable {
        let rawValue: Int
        static let command = Modifiers(rawValue: 1 << 0)
        static let option  = Modifiers(rawValue: 1 << 1)
        static let control = Modifiers(rawValue: 1 << 2)
        static let shift   = Modifiers(rawValue: 1 << 3)
    }

    var nsModifierFlags: NSEvent.ModifierFlags {
        var flags: NSEvent.ModifierFlags = []
        if modifiers.contains(.command) { flags.insert(.command) }
        if modifiers.contains(.option)  { flags.insert(.option) }
        if modifiers.contains(.control) { flags.insert(.control) }
        if modifiers.contains(.shift)   { flags.insert(.shift) }
        return flags
    }

    var displayString: String {
        var s = ""
        if modifiers.contains(.control) { s += "⌃" }
        if modifiers.contains(.option)  { s += "⌥" }
        if modifiers.contains(.shift)   { s += "⇧" }
        if modifiers.contains(.command) { s += "⌘" }
        if let code = keyCode {
            s += Self.keyName(for: code)
        }
        return s
    }

    private static func keyName(for code: UInt16) -> String {
        switch code {
        case 49: return "Space"
        case 15: return "R"
        case 36: return "Return"
        case 53: return "Esc"
        default: return "?"
        }
    }

    static let optionCommand = HotkeyChord(modifiers: [.option, .command], keyCode: nil)
    static let optionSpace   = HotkeyChord(modifiers: [.option],           keyCode: 49)
    static let commandShiftR = HotkeyChord(modifiers: [.command, .shift],  keyCode: 15)
    static let commandControlR = HotkeyChord(modifiers: [.command, .control], keyCode: 15)

    static let presets: [HotkeyChord] = [
        .optionCommand,
        .optionSpace,
        .commandShiftR,
        .commandControlR
    ]
}

// MARK: - App Preferences

final class AppPreferences: ObservableObject {
    private static let defaults = UserDefaults.standard

    private enum Key {
        static let hotkeyChord = "pref.hotkeyChord"
        static let launchOnStartup = "pref.launchOnStartup"
        static let outputFolderBookmark = "pref.outputFolderBookmark"
        static let activeModelId = "pref.activeModelId"
        static let hasCompletedOnboarding = "pref.hasCompletedOnboarding"
        static let autoPasteEnabled = "pref.autoPasteEnabled"
    }

    @Published var hotkeyChord: HotkeyChord {
        didSet {
            if let data = try? JSONEncoder().encode(hotkeyChord) {
                Self.defaults.set(data, forKey: Key.hotkeyChord)
            }
        }
    }

    @Published var launchOnStartup: Bool {
        didSet { Self.defaults.set(launchOnStartup, forKey: Key.launchOnStartup) }
    }

    @Published var outputSaveLocation: URL {
        didSet { saveOutputBookmark() }
    }

    @Published var activeModelId: String {
        didSet { Self.defaults.set(activeModelId, forKey: Key.activeModelId) }
    }

    @Published var hasCompletedOnboarding: Bool {
        didSet { Self.defaults.set(hasCompletedOnboarding, forKey: Key.hasCompletedOnboarding) }
    }

    @Published var autoPasteEnabled: Bool {
        didSet { Self.defaults.set(autoPasteEnabled, forKey: Key.autoPasteEnabled) }
    }

    init() {
        if let data = Self.defaults.data(forKey: Key.hotkeyChord),
           let chord = try? JSONDecoder().decode(HotkeyChord.self, from: data) {
            self.hotkeyChord = chord
        } else {
            self.hotkeyChord = .optionCommand
        }

        self.launchOnStartup = Self.defaults.bool(forKey: Key.launchOnStartup)
        self.activeModelId = (Self.defaults.string(forKey: Key.activeModelId)) ?? "tiny.en"
        self.hasCompletedOnboarding = Self.defaults.bool(forKey: Key.hasCompletedOnboarding)

        if Self.defaults.object(forKey: Key.autoPasteEnabled) == nil {
            self.autoPasteEnabled = true
        } else {
            self.autoPasteEnabled = Self.defaults.bool(forKey: Key.autoPasteEnabled)
        }

        let defaultFolder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("FloatingRecorder Transcriptions")

        if let bookmarkData = Self.defaults.data(forKey: Key.outputFolderBookmark) {
            var isStale = false
            if let resolved = try? URL(
                resolvingBookmarkData: bookmarkData,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            ) {
                _ = resolved.startAccessingSecurityScopedResource()
                self.outputSaveLocation = resolved
            } else {
                self.outputSaveLocation = defaultFolder
            }
        } else {
            self.outputSaveLocation = defaultFolder
        }
    }

    private func saveOutputBookmark() {
        do {
            let data = try outputSaveLocation.bookmarkData(
                options: [.withSecurityScope],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            Self.defaults.set(data, forKey: Key.outputFolderBookmark)
        } catch {
            Log.app.error("Failed to save output folder bookmark: \(error.localizedDescription)")
        }
    }
}
