import SwiftUI
import ServiceManagement
import CoreGraphics
import Carbon
import ApplicationServices
import Combine
import HotKey

@main
struct FloatingRecorderApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState.shared
    
    var body: some Scene {
        // Main app window (Preferences and History)
        WindowGroup("FloatingRecorder") {
            MainAppView()
                .environmentObject(appState)
                .frame(minWidth: 800, minHeight: 600)
        }
        .windowStyle(DefaultWindowStyle())
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) {
                // Remove "New" menu item since we don't need it
            }
        }
    }
}

// MARK: - App State Management
class AppState: ObservableObject {
    static let shared = AppState()
    
    @Published var preferences = AppPreferences()
    @Published var history = TranscriptionHistory()
    @Published var isFloatingWindowVisible = false
    
    // Shared instances for both windows
    var audioRecorder = AudioRecorder()
    let transcriber = WhisperTranscriber()
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        // Forward changes from the audioRecorder to any views observing AppState
        audioRecorder.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
        
        // Forward changes from the history to any views observing AppState
        history.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }
}

// MARK: - App Preferences Model
struct AppPreferences {
    var globalHotkey: GlobalHotkey = .optionSpacebar
    var launchOnStartup: Bool = false
    var outputSaveLocation: URL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("FloatingRecorder Transcriptions")
    
    enum GlobalHotkey: String, CaseIterable {
        case commandControlR = "⌘⌃R"
        case commandShiftR = "⌘⇧R"
        case optionSpacebar = "⌥Space"
        
        var keyCode: UInt16 {
            switch self {
            case .commandControlR: return 15 // R
            case .commandShiftR: return 15 // R
            case .optionSpacebar: return 49 // Space
            }
        }
        
        var modifierFlags: NSEvent.ModifierFlags {
            switch self {
            case .commandControlR: return [.command, .control]
            case .commandShiftR: return [.command, .shift]
            case .optionSpacebar: return [.option]
            }
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var floatingWindow: NSWindow?
    var floatingWindowController: NSWindowController?
    var floatingWindowDelegate: FloatingWindowDelegate?
    var statusItem: NSStatusItem?
    var globalHotkeyManager: GlobalHotkeyManager?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        setupGlobalHotkey()
        createFloatingWindow()
        
        // Listen for permission changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(restartHotkeyMonitoring),
            name: NSNotification.Name("RestartHotkeyMonitoring"),
            object: nil
        )
        
        // Listen for close floating recorder notification
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleCloseFloatingRecorder),
            name: NSNotification.Name("CloseFloatingRecorder"),
            object: nil
        )
        
        // Don't show main window automatically - let user open it via menu bar
        hideMainWindow()
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            showMainWindow()
        }
        return true
    }
    
    private func createFloatingWindow() {
        // Create the floating window (start with idle state size)
        let windowRect = NSRect(x: 0, y: 0, width: 120, height: 120)
        
        floatingWindow = FloatingWindow(
            contentRect: windowRect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        guard let window = floatingWindow else { return }
        
        // Configure window properties
        window.level = .floating
        window.isOpaque = false
        window.backgroundColor = NSColor.clear
        window.hasShadow = true
        window.ignoresMouseEvents = false
        window.isMovableByWindowBackground = true
        window.titlebarAppearsTransparent = true
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]
        window.acceptsMouseMovedEvents = true
        
        // Set up custom key handling for the floating window
        floatingWindowDelegate = FloatingWindowDelegate(appDelegate: self)
        window.delegate = floatingWindowDelegate
        
        // Create the content view with shared app state
        let contentView = FloatingRecorderView()
            .environmentObject(AppState.shared)
        
        let hostingView = NSHostingView(rootView: contentView)
        hostingView.frame = windowRect
        window.contentView = hostingView
            
            // Center the window
            if let screen = NSScreen.main {
                let screenRect = screen.frame
                let x = screenRect.midX - windowRect.width / 2
                let y = screenRect.midY - windowRect.height / 2
                window.setFrame(NSRect(x: x, y: y, width: windowRect.width, height: windowRect.height), display: true)
            }
        
        // Create window controller
        floatingWindowController = NSWindowController(window: window)
        
        // Initially hide the window
        window.orderOut(nil)
    }
    
    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "mic", accessibilityDescription: "FloatingRecorder")
            button.action = #selector(statusItemClicked)
            button.target = self
        }
        
        setupMenuBarMenu()
    }
    
    private func setupMenuBarMenu() {
        let menu = NSMenu()
        
        let hotkey = AppState.shared.preferences.globalHotkey
        
        menu.addItem(NSMenuItem(title: "Start Recording (\(hotkey.rawValue))", action: #selector(toggleFloatingRecorder), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Show Main Window", action: #selector(showMainWindow), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Preferences", action: #selector(showPreferences), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q"))
        
        statusItem?.menu = menu
    }
    
    private func setupGlobalHotkey() {
        // Stop existing global hotkey manager
        globalHotkeyManager?.stopMonitoring()
        
        let hotkey = AppState.shared.preferences.globalHotkey
        
        // Create new global hotkey manager
        globalHotkeyManager = GlobalHotkeyManager(hotkey: hotkey) { [weak self] in
            self?.toggleFloatingRecorder()
        }
        
        // Start monitoring - HotKey library handles permissions automatically
        if let success = globalHotkeyManager?.startMonitoring(), !success {
            print("Failed to start global hotkey monitoring.")
        }
    }
    
    private func showAccessibilityPermissionAlert() {
        let alert = NSAlert()
        alert.messageText = "Accessibility Permission Required"
        alert.informativeText = """
        FloatingRecorder needs accessibility permission to register global hotkeys (⌥Space).

        Steps to enable:
        1. Click "Open System Settings" below
        2. Find "FloatingRecorder" in the list
        3. Toggle it ON
        4. Restart the app if needed

        Without this permission, you'll need to use the menu bar to access recording features.
        """
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Continue Without Hotkeys")
        alert.addButton(withTitle: "Quit App")
        
        let response = alert.runModal()
        switch response {
        case .alertFirstButtonReturn:
            // Open System Settings
            if #available(macOS 13.0, *) {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
            } else {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
            }
        case .alertSecondButtonReturn:
            // Continue without hotkeys - do nothing
            break
        case .alertThirdButtonReturn:
            // Quit app
            NSApplication.shared.terminate(nil)
        default:
            break
        }
    }
    
    @objc private func statusItemClicked() {
        // This will show the menu
    }
    
    @objc private func toggleFloatingRecorder() {
        print("🎬 toggleFloatingRecorder called!")
        guard let window = floatingWindow else { 
            print("❌ No floating window found")
            return 
        }
        
        if window.isVisible {
            print("🫥 Hiding floating window")
            hideFloatingWindow()
        } else {
            print("🎭 Showing floating window")
            showFloatingWindow()
        }
    }
    
    private func showFloatingWindow() {
        guard let window = floatingWindow else { return }
        
        // Update menu bar icon to show recording state
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: "Recording")
        }
        
        window.orderFrontRegardless()
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(window.contentView)
        
        // Post notification to start recording
        NotificationCenter.default.post(name: NSNotification.Name("ShowFloatingRecorder"), object: nil)
    }
    
    func hideFloatingWindow() {
        guard let window = floatingWindow else { return }
        
        // Update menu bar icon back to idle
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "mic", accessibilityDescription: "FloatingRecorder")
        }
        
        window.orderOut(nil)
        
        // Post notification to stop recording if needed
        NotificationCenter.default.post(name: NSNotification.Name("HideFloatingRecorder"), object: nil)
    }
    
    @objc private func showMainWindow() {
        // Find and show the main window
        for window in NSApplication.shared.windows {
            if window.title == "FloatingRecorder" && window != floatingWindow {
                window.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
                return
            }
        }
    }
    
    private func hideMainWindow() {
        // Hide the main window on startup so app starts with just menu bar
        for window in NSApplication.shared.windows {
            if window.title == "FloatingRecorder" && window != floatingWindow {
                window.orderOut(nil)
                return
            }
        }
    }
    
    @objc private func showPreferences() {
        showMainWindow()
        NotificationCenter.default.post(name: NSNotification.Name("ShowPreferences"), object: nil)
    }
    
    @objc private func restartHotkeyMonitoring() {
        print("🔄 Restarting hotkey monitoring...")
        setupGlobalHotkey()
        // Refresh the menu to show updated status
        setupMenuBarMenu()
    }
    

    
    @objc private func handleCloseFloatingRecorder() {
        hideFloatingWindow()
    }
    
    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}

// MARK: - Floating Window Delegate
class FloatingWindowDelegate: NSObject, NSWindowDelegate {
    weak var appDelegate: AppDelegate?
    private var keyMonitor: Any?
    private var globalKeyMonitor: Any?
    
    init(appDelegate: AppDelegate) {
        self.appDelegate = appDelegate
        super.init()
        setupGlobalKeyMonitoring()
    }
    
    private func setupGlobalKeyMonitoring() {
        // Monitor Option+Esc globally to close floating window
        globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.modifierFlags.contains(.option) && event.keyCode == 53 { // 53 is Esc key
                DispatchQueue.main.async {
                    self?.appDelegate?.hideFloatingWindow()
                }
            }
        }
        
        // Also monitor locally
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.modifierFlags.contains(.option) && event.keyCode == 53 { // 53 is Esc key
                DispatchQueue.main.async {
                    self?.appDelegate?.hideFloatingWindow()
                }
                return nil // Consume the event
            }
            return event
        }
    }
    
    func windowDidBecomeKey(_ notification: Notification) {
        // Window became key - ensure monitoring is active
        if keyMonitor == nil {
            setupGlobalKeyMonitoring()
        }
    }
    
    func windowDidResignKey(_ notification: Notification) {
        // Keep monitoring active even when window loses focus
        // This ensures Option+Esc works even when the window is not focused
    }
    
    deinit {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = globalKeyMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}

// MARK: - Custom Window Class
class FloatingWindow: NSWindow {
    override var canBecomeKey: Bool {
        return true
    }
    
    override var canBecomeMain: Bool {
        return false
    }
}

// MARK: - Global Hotkey Manager (using HotKey library)
class GlobalHotkeyManager {
    private var hotKey: HotKey?
    private var hotkeyCallback: (() -> Void)?
    private var hotKeyConfig: AppPreferences.GlobalHotkey
    
    init(hotkey: AppPreferences.GlobalHotkey, callback: @escaping () -> Void) {
        self.hotKeyConfig = hotkey
        self.hotkeyCallback = callback
    }
    
    func startMonitoring() -> Bool {
        print("🔧 Starting global hotkey monitoring for \(hotKeyConfig.rawValue)")
        
        // Stop any existing hotkey first
        stopMonitoring()
        
        // Convert our hotkey config to HotKey format
        let key = convertToHotKeyKey(keyCode: hotKeyConfig.keyCode)
        let modifiers = convertToHotKeyModifiers(flags: hotKeyConfig.modifierFlags)
        
        // Create HotKey instance
        hotKey = HotKey(key: key, modifiers: modifiers)
        
        // Set up the callback
        hotKey?.keyDownHandler = { [weak self] in
            print("🎯 HotKey triggered!")
            self?.hotkeyCallback?()
        }
        
        if hotKey != nil {
            print("✅ Global hotkey monitoring active for \(hotKeyConfig.rawValue)")
            return true
        } else {
            print("❌ Failed to create global hotkey for \(hotKeyConfig.rawValue)")
            return false
        }
    }
    
    func stopMonitoring() {
        print("🛑 Stopping global hotkey monitoring...")
        hotKey = nil // HotKey automatically unregisters on dealloc
        print("✅ Global hotkey monitoring stopped successfully")
    }
    
    private func convertToHotKeyKey(keyCode: UInt16) -> Key {
        // Convert key codes to HotKey.Key enum
        switch keyCode {
        case 15: return .r
        case 49: return .space
        default:
            print("⚠️ Unknown key code \(keyCode), defaulting to .space")
            return .space
        }
    }
    
    private func convertToHotKeyModifiers(flags: NSEvent.ModifierFlags) -> NSEvent.ModifierFlags {
        // HotKey uses the same NSEvent.ModifierFlags, so we can return them directly
        return flags
    }
    
    deinit {
        stopMonitoring()
    }
} 