import SwiftUI
import ServiceManagement
import AVFoundation
import AppKit
import UniformTypeIdentifiers

struct MainAppView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var preferences: AppPreferences
    @State private var selectedPanel: SidebarPanel = .preferences
    @State private var onboardingDismissBinding = true

    var body: some View {
        Group {
            if preferences.hasCompletedOnboarding {
                mainChrome
            } else {
                OnboardingView(isPresented: $onboardingDismissBinding)
                    .environmentObject(appState)
                    .environmentObject(preferences)
                    .environmentObject(appState.modelManager)
            }
        }
    }

    /// Preferences are not loaded under first-run onboarding (avoids duplicate Accessibility UI and timers).
    private var mainChrome: some View {
        NavigationSplitView {
            SidebarView(selectedPanel: $selectedPanel)
                .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 250)
        } detail: {
            Group {
                switch selectedPanel {
                case .preferences: PreferencesView()
                case .history:     HistoryView()
                }
            }
            .navigationTitle(selectedPanel.title)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationSplitViewStyle(.balanced)
        .onReceive(NotificationCenter.default.publisher(for: .showPreferences)) { _ in
            selectedPanel = .preferences
        }
    }
}

enum SidebarPanel: String, CaseIterable {
    case preferences
    case history

    var title: String {
        switch self {
        case .preferences: return "Preferences"
        case .history:     return "History"
        }
    }

    var icon: String {
        switch self {
        case .preferences: return "gear"
        case .history:     return "clock.arrow.circlepath"
        }
    }
}

struct SidebarView: View {
    @Binding var selectedPanel: SidebarPanel

    var body: some View {
        List(SidebarPanel.allCases, id: \.rawValue, selection: $selectedPanel) { panel in
            NavigationLink(value: panel) {
                Label(panel.title, systemImage: panel.icon)
            }
        }
        .navigationTitle("FloatingRecorder")
        .listStyle(.sidebar)
    }
}

// MARK: - Preferences

struct PreferencesView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var preferences: AppPreferences
    @EnvironmentObject private var models: ModelManager

    @State private var showingFolderPicker = false
    @State private var accessibilityTrusted: Bool = AccessibilityPermission.isTrusted
    @State private var micStatus: AVAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .audio)

    private let permissionPollTimer = Timer.publish(every: 1.5, on: .main, in: .common).autoconnect()

    var body: some View {
        Form {
            aboutSection
            generalSection
            shortcutsSection
            modelsSection
            privacySection
        }
        .formStyle(.grouped)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .fileImporter(
            isPresented: $showingFolderPicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    _ = url.startAccessingSecurityScopedResource()
                    preferences.outputSaveLocation = url
                }
            case .failure(let error):
                Log.ui.error("Folder pick failed: \(error.localizedDescription)")
            }
        }
        .onReceive(permissionPollTimer) { _ in
            accessibilityTrusted = AccessibilityPermission.isTrusted
            micStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        }
    }

    // MARK: Sections

    private var aboutSection: some View {
        Section {
            HStack(spacing: 16) {
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.blue)
                    .symbolRenderingMode(.hierarchical)

                VStack(alignment: .leading, spacing: 2) {
                    Text("FloatingRecorder")
                        .font(.title2.weight(.semibold))
                    Text("Local voice-to-text powered by Whisper")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("Version \(appVersion) (\(appBuild))")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                Spacer()
            }
            .padding(.vertical, 4)
        }
    }

    private var generalSection: some View {
        Section("General") {
            Toggle("Launch on startup", isOn: Binding(
                get: { preferences.launchOnStartup },
                set: { newValue in
                    preferences.launchOnStartup = newValue
                    toggleLaunchOnStartup(newValue)
                }
            ))

            Toggle("Auto-paste into focused text field", isOn: Binding(
                get: { preferences.autoPasteEnabled },
                set: { preferences.autoPasteEnabled = $0 }
            ))

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Output save location")
                    Spacer()
                    Button("Choose Folder…") { showingFolderPicker = true }
                        .buttonStyle(.borderless)
                }
                Text(preferences.outputSaveLocation.path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .truncationMode(.middle)
            }
        }
    }

    private var shortcutsSection: some View {
        Section("Shortcut") {
            HStack {
                Text("Global hotkey")
                Spacer()
                Picker("", selection: Binding(
                    get: { preferences.hotkeyChord },
                    set: { preferences.hotkeyChord = $0 }
                )) {
                    ForEach(HotkeyChord.presets, id: \.self) { chord in
                        Text(chord.displayString).tag(chord)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 140)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Tap to toggle recording. Hold to push-to-talk (releases automatically transcribes and pastes).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                statusDot(ok: accessibilityTrusted)
                Text(accessibilityTrusted
                     ? "Accessibility permission granted"
                     : "Accessibility permission required for global hotkey")
                    .font(.callout)
                Spacer()
                if !accessibilityTrusted {
                    Button("Open Settings") {
                        AccessibilityPermission.openSettings()
                    }
                }
            }

            if !accessibilityTrusted {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .foregroundStyle(.orange)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("macOS only detects Accessibility permission after the app restarts.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Button("Quit & Relaunch") {
                            AccessibilityPermission.relaunchApp()
                        }
                        .controlSize(.small)
                    }
                    Spacer()
                }
            }
        }
    }

    private var modelsSection: some View {
        Section("Speech models") {
            Text("Whisper models run locally on your Mac. Larger models are more accurate but slower and take more disk space.")
                .font(.caption)
                .foregroundStyle(.secondary)

            ForEach(models.catalog) { model in
                ModelRow(model: model)
                    .environmentObject(models)
                    .environmentObject(preferences)
            }
        }
    }

    private var privacySection: some View {
        Section("Privacy") {
            HStack(spacing: 10) {
                statusDot(ok: micStatus == .authorized)
                Text(micStatusText)
                Spacer()
                if micStatus != .authorized {
                    Button("Open Settings") {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                }
            }

            Text("Audio and transcriptions never leave your Mac.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func statusDot(ok: Bool) -> some View {
        Circle()
            .fill(ok ? Color.green : Color.orange)
            .frame(width: 10, height: 10)
    }

    private var micStatusText: String {
        switch micStatus {
        case .authorized:  return "Microphone permission granted"
        case .denied:      return "Microphone permission denied"
        case .restricted:  return "Microphone access is restricted"
        case .notDetermined: return "Microphone permission not requested yet"
        @unknown default:  return "Microphone status unknown"
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var appBuild: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    private func toggleLaunchOnStartup(_ enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                Log.app.error("Launch on startup toggle failed: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Model row

struct ModelRow: View {
    let model: WhisperModel
    @EnvironmentObject private var models: ModelManager
    @EnvironmentObject private var preferences: AppPreferences

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(model.displayName)
                        .font(.system(size: 13, weight: .medium))
                    if preferences.activeModelId == model.id && isInstalled {
                        Text("Active")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue, in: Capsule())
                    }
                }
                Text("\(model.notes) • \(sizeText)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if case .downloading(let progress) = state {
                    ProgressView(value: progress)
                        .frame(maxWidth: 240)
                }
                if case .failed(let msg) = state {
                    Text(msg).font(.caption).foregroundStyle(.red)
                }
            }
            Spacer()
            actionButtons
        }
        .padding(.vertical, 4)
    }

    private var state: ModelState { models.states[model.id] ?? .notInstalled }
    private var isInstalled: Bool {
        if case .installed = state { return true }
        return false
    }

    private var sizeText: String {
        if model.approximateMB < 1024 {
            return "~\(model.approximateMB) MB"
        }
        return String(format: "~%.1f GB", Double(model.approximateMB) / 1024.0)
    }

    @ViewBuilder
    private var actionButtons: some View {
        switch state {
        case .notInstalled:
            Button("Download") { models.download(model) }
                .buttonStyle(.bordered)
        case .installed:
            HStack(spacing: 6) {
                if preferences.activeModelId != model.id {
                    Button("Use") { models.setActive(model) }
                        .buttonStyle(.bordered)
                }
                Button(role: .destructive) {
                    models.delete(model)
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .help("Remove this model")
            }
        case .downloading(let progress):
            HStack(spacing: 6) {
                Text("\(Int(progress * 100))%")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                Button("Cancel") { models.cancelDownload(model) }
                    .buttonStyle(.borderless)
            }
        case .verifying:
            Text("Verifying…")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .failed:
            Button("Retry") { models.download(model) }
                .buttonStyle(.bordered)
        }
    }
}

// MARK: - History

struct HistoryView: View {
    @EnvironmentObject private var appState: AppState
    @State private var searchText = ""

    var filteredHistory: [TranscriptionItem] {
        if searchText.isEmpty { return appState.history.items }
        return appState.history.items.filter {
            $0.text.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search transcriptions…", text: $searchText)
                    .textFieldStyle(.plain)
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(12)
            .background(Color(NSColor.controlBackgroundColor))
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundStyle(Color(NSColor.separatorColor)),
                alignment: .bottom
            )

            if filteredHistory.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: searchText.isEmpty ? "waveform" : "magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text(searchText.isEmpty ? "No transcriptions yet" : "No matches")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text(searchText.isEmpty
                         ? "Press your global hotkey to start recording"
                         : "Try a different search")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(filteredHistory) { item in
                        HistoryRowView(item: item,
                                       onCopy: {
                            let pb = NSPasteboard.general
                            pb.clearContents()
                            pb.setString(item.text, forType: .string)
                        },
                                       onDelete: { appState.history.removeTranscription(item) }
                        )
                    }
                }
                .listStyle(.inset)
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("Clear All History") { appState.history.clearHistory() }
                        .disabled(appState.history.items.isEmpty)
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
    }
}

struct HistoryRowView: View {
    let item: TranscriptionItem
    let onCopy: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(item.timestamp, style: .date)
                    .font(.caption).foregroundStyle(.secondary)
                Text(item.timestamp, style: .time)
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button(action: onCopy) { Image(systemName: "doc.on.doc") }
                    .buttonStyle(.borderless).help("Copy to clipboard")
                Button(action: onDelete) { Image(systemName: "trash").foregroundStyle(.red) }
                    .buttonStyle(.borderless).help("Delete transcription")
            }
            Text(item.text)
                .font(.body)
                .lineLimit(3)
                .textSelection(.enabled)
        }
        .padding(.vertical, 4)
    }
}
