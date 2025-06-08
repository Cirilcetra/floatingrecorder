import SwiftUI
import ServiceManagement

struct MainAppView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selectedPanel: SidebarPanel = .preferences
    
    var body: some View {
        NavigationSplitView {
            // Sidebar
            SidebarView(selectedPanel: $selectedPanel)
                .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 250)
        } detail: {
            // Detail view
            Group {
                switch selectedPanel {
                case .preferences:
                    PreferencesView()
                case .history:
                    HistoryView()
                }
            }
            .navigationTitle(selectedPanel.title)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationSplitViewStyle(.balanced)
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShowPreferences"))) { _ in
            selectedPanel = .preferences
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ToggleFloatingRecorder"))) { _ in
            toggleFloatingWindow()
        }
    }
    
    private func toggleFloatingWindow() {
        // This will be handled by the floating window itself
        // Just update the state here
        appState.isFloatingWindowVisible.toggle()
    }
}

// MARK: - Sidebar Panel Enum
enum SidebarPanel: String, CaseIterable {
    case preferences = "preferences"
    case history = "history"
    
    var title: String {
        switch self {
        case .preferences: return "Preferences"
        case .history: return "History"
        }
    }
    
    var icon: String {
        switch self {
        case .preferences: return "gear"
        case .history: return "clock.arrow.circlepath"
        }
    }
}

// MARK: - Sidebar View
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

// MARK: - Preferences View
struct PreferencesView: View {
    @EnvironmentObject private var appState: AppState
    @State private var showingFolderPicker = false
    
    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "waveform")
                            .font(.system(size: 32))
                            .foregroundColor(.blue)
                        
                        VStack(alignment: .leading) {
                            Text("FloatingRecorder")
                                .font(.title2)
                                .fontWeight(.semibold)
                            
                            Text("Voice transcription powered by Whisper")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    
                    Text("This app uses OpenAI's Whisper model (base.en) for accurate speech-to-text transcription. The model runs locally on your device for privacy.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }
                .padding(.vertical, 8)
            } header: {
                Text("About")
            }
            
            Section {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Global Hotkey")
                        Spacer()
                        Picker("", selection: $appState.preferences.globalHotkey) {
                            ForEach(AppPreferences.GlobalHotkey.allCases, id: \.self) { hotkey in
                                Text(hotkey.rawValue).tag(hotkey)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 120)
                    }
                    
                    Toggle("Launch on Startup", isOn: $appState.preferences.launchOnStartup)
                        .onChange(of: appState.preferences.launchOnStartup) { _, newValue in
                            toggleLaunchOnStartup(newValue)
                        }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Output Save Location")
                            Spacer()
                            Button("Choose Folder") {
                                showingFolderPicker = true
                            }
                            .buttonStyle(.borderless)
                        }
                        
                        Text(appState.preferences.outputSaveLocation.path)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                            .truncationMode(.middle)
                    }
                }
            } header: {
                Text("Settings")
            }
            
            Section {
                HStack {
                    Spacer()
                    Button("Quit FloatingRecorder") {
                        NSApplication.shared.terminate(nil)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    Spacer()
                }
                .padding(.vertical, 8)
            }
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
                    appState.preferences.outputSaveLocation = url
                }
            case .failure(let error):
                print("Error selecting folder: \(error)")
            }
        }
    }
    
    private func toggleLaunchOnStartup(_ enabled: Bool) {
        if #available(macOS 13.0, *) {
            if enabled {
                try? SMAppService.mainApp.register()
            } else {
                try? SMAppService.mainApp.unregister()
            }
        }
    }
}

// MARK: - History View
struct HistoryView: View {
    @EnvironmentObject private var appState: AppState
    @State private var searchText = ""
    
    var filteredHistory: [TranscriptionItem] {
        if searchText.isEmpty {
            return appState.history.items
        } else {
            return appState.history.items.filter { item in
                item.text.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search transcriptions...", text: $searchText)
                    .textFieldStyle(.plain)
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(12)
            .background(Color(NSColor.controlBackgroundColor))
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(Color(NSColor.separatorColor)),
                alignment: .bottom
            )
            
            // History list
            if filteredHistory.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: searchText.isEmpty ? "waveform" : "magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    
                    Text(searchText.isEmpty ? "No transcriptions yet" : "No matching transcriptions")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text(searchText.isEmpty ? 
                         "Start recording with your global hotkey to see transcriptions here" :
                         "Try adjusting your search terms")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(filteredHistory) { item in
                        HistoryRowView(item: item) {
                            // Copy action
                            appState.transcriber.pasteText(item.text)
                        } onDelete: {
                            // Delete action
                            print("DEBUG: Delete button clicked for item: \(item.id)")
                            appState.history.removeTranscription(item)
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("Clear All History") {
                        appState.history.clearHistory()
                    }
                    .disabled(appState.history.items.isEmpty)
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
    }
}

// MARK: - History Row View
struct HistoryRowView: View {
    let item: TranscriptionItem
    let onCopy: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(item.timestamp, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(item.timestamp, style: .time)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button(action: onCopy) {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(.borderless)
                .help("Copy to clipboard")
                
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .buttonStyle(.borderless)
                .help("Delete transcription")
            }
            
            Text(item.text)
                .font(.body)
                .lineLimit(3)
                .textSelection(.enabled)
        }
        .padding(.vertical, 4)
    }
} 