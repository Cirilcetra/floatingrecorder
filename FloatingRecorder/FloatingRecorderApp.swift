import SwiftUI
import ServiceManagement
import CoreGraphics
import Carbon
import ApplicationServices
import Combine
import AppKit

@main
struct FloatingRecorderApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState.shared

    var body: some Scene {
        WindowGroup("FloatingRecorder") {
            MainAppView()
                .environmentObject(appState)
                .environmentObject(appState.preferences)
                .environmentObject(appState.modelManager)
                .frame(minWidth: 820, minHeight: 600)
        }
        .windowStyle(DefaultWindowStyle())
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
    }
}

// MARK: - App State

final class AppState: ObservableObject {
    static let shared = AppState()

    let preferences = AppPreferences()
    let history = TranscriptionHistory()
    let modelManager: ModelManager
    let audioRecorder = AudioRecorder()
    let transcriber: WhisperTranscriber

    @Published var isFloatingWindowVisible = false
    @Published var lastActiveApp: NSRunningApplication?
    @Published var isPushToTalk: Bool = false

    private var cancellables = Set<AnyCancellable>()

    private init() {
        let mm = ModelManager(preferences: preferences)
        self.modelManager = mm
        self.transcriber = WhisperTranscriber(modelManager: mm)

        audioRecorder.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        history.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        modelManager.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        preferences.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }
}

// MARK: - App Delegate

final class AppDelegate: NSObject, NSApplicationDelegate {
    var floatingWindow: NSWindow?
    var floatingWindowController: NSWindowController?
    var floatingWindowDelegate: FloatingWindowDelegate?
    var statusItem: NSStatusItem?
    var hotkeyEngine: HotkeyEngine?

    private var cancellables = Set<AnyCancellable>()

    func applicationWillFinishLaunching(_ notification: Notification) {
        FileLogger.recordLaunchBanner(axTrusted: AccessibilityPermission.isTrusted)
        enforceSingleInstanceIfNeeded()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        setupHotkeyEngine()
        createFloatingWindow()
        observePreferences()
        observeRecordingState()
        observeOnboardingCompletion()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleCloseFloatingRecorder),
            name: .closeFloating,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDidBecomeActive),
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )

        Log.app.info("applicationDidFinishLaunching AXTrusted=\(AccessibilityPermission.isTrusted)")

        if AppState.shared.preferences.hasCompletedOnboarding {
            hideMainWindow()
        } else {
            // Surface the onboarding sheet on first launch.
            DispatchQueue.main.async { [weak self] in
                self?.showMainWindow()
            }
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { showMainWindow() }
        return true
    }

    private func observePreferences() {
        AppState.shared.preferences.$hotkeyChord
            .dropFirst()
            .sink { [weak self] _ in
                self?.setupHotkeyEngine()
                self?.setupMenuBarMenu()
            }
            .store(in: &cancellables)
    }

    /// After first-run onboarding, start the hotkey engine if Accessibility is now trusted and hide the main window.
    private func observeOnboardingCompletion() {
        AppState.shared.preferences.$hasCompletedOnboarding
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] completed in
                guard completed else { return }
                DispatchQueue.main.async {
                    self?.setupHotkeyEngine()
                    self?.hideMainWindow()
                    Log.app.info("Onboarding marked complete — hotkey engine refreshed, main window hidden")
                }
            }
            .store(in: &cancellables)
    }

    @objc private func handleDidBecomeActive() {
        guard AppState.shared.preferences.hasCompletedOnboarding else { return }
        setupHotkeyEngine()
    }

    private func observeRecordingState() {
        AppState.shared.audioRecorder.$isRecording
            .receive(on: DispatchQueue.main)
            .sink { [weak self] recording in
                guard let button = self?.statusItem?.button else { return }
                button.image = NSImage(
                    systemSymbolName: recording ? "mic.fill" : "mic",
                    accessibilityDescription: "FloatingRecorder"
                )
                if recording {
                    button.contentTintColor = .systemRed
                } else {
                    button.contentTintColor = nil
                }
            }
            .store(in: &cancellables)
    }

    private func createFloatingWindow() {
        let windowRect = NSRect(x: 0, y: 0, width: 120, height: 120)

        floatingWindow = FloatingWindow(
            contentRect: windowRect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        guard let window = floatingWindow else { return }

        window.level = .floating
        window.isOpaque = false
        window.backgroundColor = NSColor.clear
        window.hasShadow = true
        window.ignoresMouseEvents = false
        window.isMovableByWindowBackground = true
        window.titlebarAppearsTransparent = true
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]
        window.acceptsMouseMovedEvents = true

        floatingWindowDelegate = FloatingWindowDelegate(appDelegate: self)
        window.delegate = floatingWindowDelegate

        let contentView = FloatingRecorderView()
            .environmentObject(AppState.shared)
            .environmentObject(AppState.shared.preferences)

        let hostingView = NSHostingView(rootView: contentView)
        hostingView.frame = windowRect
        window.contentView = hostingView

        if let screen = NSScreen.main {
            let screenRect = screen.frame
            let x = screenRect.midX - windowRect.width / 2
            let y = screenRect.midY - windowRect.height / 2
            window.setFrame(NSRect(x: x, y: y, width: windowRect.width, height: windowRect.height), display: true)
        }

        floatingWindowController = NSWindowController(window: window)
        window.orderOut(nil)
    }

    private static func applyTargets(_ menu: NSMenu, to target: AnyObject) {
        for item in menu.items {
            if item.action != nil {
                item.target = target
            }
            if let sub = item.submenu {
                applyTargets(sub, to: target)
            }
        }
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

    func setupMenuBarMenu() {
        let menu = NSMenu()

        let chord = AppState.shared.preferences.hotkeyChord
        menu.addItem(NSMenuItem(title: "Toggle Recording (\(chord.displayString))", action: #selector(toggleFloatingRecorder), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())

        let modelName = AppState.shared.modelManager.activeModel?.displayName ?? "No model"
        let modelItem = NSMenuItem(title: "Model: \(modelName)", action: nil, keyEquivalent: "")
        modelItem.isEnabled = false
        menu.addItem(modelItem)
        menu.addItem(NSMenuItem.separator())

        menu.addItem(NSMenuItem(title: "Show Main Window", action: #selector(showMainWindow), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Preferences…", action: #selector(showPreferences), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())

        let diagItem = NSMenuItem(title: "Diagnostics", action: nil, keyEquivalent: "")
        let diagMenu = NSMenu()
        diagMenu.addItem(withTitle: "Show Diagnostics Log…", action: #selector(showDiagnosticsLog), keyEquivalent: "")
        diagMenu.addItem(withTitle: "Reveal Log in Finder", action: #selector(revealDiagnosticsInFinder), keyEquivalent: "")
        diagMenu.addItem(withTitle: "Open Log in External Editor", action: #selector(openDiagnosticsLogExternally), keyEquivalent: "")
        diagMenu.addItem(withTitle: "Copy Log File Path", action: #selector(copyDiagnosticsLogPath), keyEquivalent: "")
        diagItem.submenu = diagMenu
        menu.addItem(diagItem)

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit FloatingRecorder", action: #selector(quitApp), keyEquivalent: "q"))

        Self.applyTargets(menu, to: self)

        statusItem?.menu = menu
    }

    private func setupHotkeyEngine() {
        hotkeyEngine?.stop()

        let chord = AppState.shared.preferences.hotkeyChord
        hotkeyEngine = HotkeyEngine(
            chord: chord,
            onTap: { [weak self] in
                DispatchQueue.main.async {
                    AppState.shared.isPushToTalk = false
                    self?.toggleFloatingRecorder()
                }
            },
            onHoldStart: { [weak self] in
                DispatchQueue.main.async {
                    AppState.shared.isPushToTalk = true
                    self?.showFloatingWindow()
                    NotificationCenter.default.post(name: .startPushToTalk, object: nil)
                }
            },
            onHoldEnd: { [weak self] in
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .stopPushToTalk, object: nil)
                    _ = self
                }
            }
        )

        hotkeyEngine?.start()
    }

    @objc private func statusItemClicked() { }

    @objc func toggleFloatingRecorder() {
        guard let window = floatingWindow else {
            Log.app.error("No floating window available")
            return
        }

        if window.isVisible {
            hideFloatingWindow()
        } else {
            showFloatingWindow()
        }
    }

    func showFloatingWindow() {
        guard let window = floatingWindow else { return }

        let front = NSWorkspace.shared.frontmostApplication
        if front?.bundleIdentifier != Bundle.main.bundleIdentifier {
            AppState.shared.lastActiveApp = front
        }

        window.orderFrontRegardless()
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(window.contentView)

        NotificationCenter.default.post(name: .showFloating, object: nil)
    }

    func hideFloatingWindow() {
        guard let window = floatingWindow else { return }
        window.orderOut(nil)
        NotificationCenter.default.post(name: .hideFloating, object: nil)
    }

    @objc func showMainWindow() {
        for window in NSApplication.shared.windows where window.title == "FloatingRecorder" && window != floatingWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
    }

    private func hideMainWindow() {
        for window in NSApplication.shared.windows where window.title == "FloatingRecorder" && window != floatingWindow {
            window.orderOut(nil)
            return
        }
    }

    @objc private func showPreferences() {
        showMainWindow()
        NotificationCenter.default.post(name: .showPreferences, object: nil)
    }

    @objc private func handleCloseFloatingRecorder() {
        hideFloatingWindow()
    }

    @objc private func quitApp() {
        Log.app.info("Quit chosen from menu")
        NSApplication.shared.terminate(nil)
    }

    @objc private func showDiagnosticsLog() {
        DiagnosticsPanel.show()
    }

    @objc private func revealDiagnosticsInFinder() {
        DiagnosticsPanel.revealLogInFinder()
    }

    @objc private func openDiagnosticsLogExternally() {
        DiagnosticsPanel.openLogExternally()
    }

    @objc private func copyDiagnosticsLogPath() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(FileLogger.logFileURL.path, forType: .string)
        Log.app.info("Copied diagnostics log path to pasteboard")
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        Log.app.info("applicationShouldTerminate — allowing quit")
        return .terminateNow
    }

    func applicationWillTerminate(_ notification: Notification) {
        FileLogger.syncWriteTerminationNotice()
        Log.app.info("applicationWillTerminate")
    }

    /// Prevent stacking many copies (e.g. repeated “Relaunch” or multiple Finder launches).
    private func enforceSingleInstanceIfNeeded() {
        guard let bid = Bundle.main.bundleIdentifier else { return }
        let myPid = ProcessInfo.processInfo.processIdentifier
        let peers = NSWorkspace.shared.runningApplications.filter { $0.bundleIdentifier == bid }
        guard peers.count > 1,
              let keeper = peers.min(by: { $0.processIdentifier < $1.processIdentifier }) else { return }

        if myPid != keeper.processIdentifier {
            Log.app.notice("Exiting duplicate instance pid=\(myPid); activating pid=\(keeper.processIdentifier)")
            if #available(macOS 14.0, *) {
                keeper.activate(options: [.activateAllWindows])
            } else {
                keeper.activate(options: [.activateIgnoringOtherApps, .activateAllWindows])
            }
            NSApp.terminate(nil)
        }
    }
}

// MARK: - Floating Window Delegate

final class FloatingWindowDelegate: NSObject, NSWindowDelegate {
    weak var appDelegate: AppDelegate?
    private var keyMonitor: Any?
    private var globalKeyMonitor: Any?

    init(appDelegate: AppDelegate) {
        self.appDelegate = appDelegate
        super.init()
        setupKeyMonitoringIfNeeded()
    }

    private func setupKeyMonitoringIfNeeded() {
        guard keyMonitor == nil && globalKeyMonitor == nil else { return }

        globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.modifierFlags.contains(.option) && event.keyCode == 53 {
                DispatchQueue.main.async {
                    self?.appDelegate?.hideFloatingWindow()
                }
            }
        }

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.modifierFlags.contains(.option) && event.keyCode == 53 {
                DispatchQueue.main.async {
                    self?.appDelegate?.hideFloatingWindow()
                }
                return nil
            }
            return event
        }
    }

    func windowDidBecomeKey(_ notification: Notification) {
        setupKeyMonitoringIfNeeded()
    }

    func windowDidResignKey(_ notification: Notification) { }

    deinit {
        if let monitor = keyMonitor { NSEvent.removeMonitor(monitor) }
        if let monitor = globalKeyMonitor { NSEvent.removeMonitor(monitor) }
    }
}

// MARK: - Floating Window

final class FloatingWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
