import AppKit
import SwiftUI

// MARK: - Log text state (shared so menu can refresh an open window)

final class DiagnosticsLogState: ObservableObject {
    static let shared = DiagnosticsLogState()

    @Published var text: String = ""
    private let maxReadBytes = 4_000_000

    func reload() {
        let url = FileLogger.logFileURL
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let result: String
            if let data = try? Data(contentsOf: url), !data.isEmpty {
                let cap = min(data.count, self.maxReadBytes)
                var s = String(decoding: data.prefix(cap), as: UTF8.self)
                if data.count > cap {
                    s = "…(truncated for this window — full file on disk)\n\n" + s
                }
                result = s
            } else {
                result = """
                (No log file yet, or it is empty.)

                Everything the app records appears here and in Console.app (filter subsystem: \(Bundle.main.bundleIdentifier ?? "FloatingRecorder")).

                Log path:
                \(url.path)
                """
            }
            DispatchQueue.main.async {
                self.text = result
            }
        }
    }
}

struct DiagnosticsLogView: View {
    @ObservedObject private var state = DiagnosticsLogState.shared

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                Text(state.text)
                    .font(.system(size: 11, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .padding(12)
            }
            Divider()
            HStack(spacing: 12) {
                Button("Refresh") { state.reload() }
                Button("Reveal in Finder") { DiagnosticsPanel.revealLogInFinder() }
                Button("Open in External Editor") { DiagnosticsPanel.openLogExternally() }
                Spacer()
                Button("Copy path") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(FileLogger.logFileURL.path, forType: .string)
                }
            }
            .padding(10)
        }
        .frame(minWidth: 560, minHeight: 420)
        .onAppear { state.reload() }
    }
}

enum DiagnosticsPanel {
    private static weak var window: NSWindow?

    static func show() {
        if let existing = window {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            DiagnosticsLogState.shared.reload()
            return
        }

        let host = NSHostingView(rootView: DiagnosticsLogView())
        host.frame = NSRect(x: 0, y: 0, width: 760, height: 520)

        let w = NSWindow(
            contentRect: host.bounds,
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        w.contentView = host
        w.title = "FloatingRecorder — Diagnostics"
        w.center()
        w.isReleasedWhenClosed = false

        window = w
        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        DiagnosticsLogState.shared.reload()
        Log.app.info("Opened diagnostics log window")
    }

    static func revealLogInFinder() {
        let url = FileLogger.logFileURL
        if FileManager.default.fileExists(atPath: url.path) {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } else {
            try? FileManager.default.createDirectory(at: FileLogger.logDirectoryURL, withIntermediateDirectories: true)
            NSWorkspace.shared.activateFileViewerSelecting([FileLogger.logDirectoryURL])
        }
    }

    static func openLogExternally() {
        let url = FileLogger.logFileURL
        if !FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.createDirectory(at: FileLogger.logDirectoryURL, withIntermediateDirectories: true)
            FileManager.default.createFile(atPath: url.path, contents: nil)
        }
        NSWorkspace.shared.open(url)
    }
}
