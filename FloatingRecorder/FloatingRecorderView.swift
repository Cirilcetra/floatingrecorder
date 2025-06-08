import SwiftUI

struct FloatingRecorderView: View {
    @EnvironmentObject private var appState: AppState
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var transcribedText: String = ""
    @State private var recordingStartTime: Date?
    @State private var currentState: RecordingState = .idle
    @State private var willAutoPaste: Bool = false
    
    enum RecordingState {
        case idle
        case listening
        case transcribing
        case completed
    }
    
    var body: some View {
        ZStack {
            // Background with clean design - no shadows
            RoundedRectangle(cornerRadius: dynamicCornerRadius)
                .fill(Color.black)
                .overlay {
                    RoundedRectangle(cornerRadius: dynamicCornerRadius)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                }
            
            // Content based on state
            switch currentState {
            case .idle:
                idleStateView
            case .listening:
                listeningStateView
            case .transcribing:
                transcribingStateView
            case .completed:
                completedStateView
            }
        }
        .frame(width: dynamicWidth, height: dynamicHeight)
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShowFloatingRecorder"))) { _ in
            // Window is being shown - check if we should auto-paste and start recording
            checkAutoPasteStatus()
            if currentState == .idle {
                startRecording()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("HideFloatingRecorder"))) { _ in
            // Window is being hidden - stop recording if active
            if currentState == .listening {
                stopRecording()
            }
        }
        .onAppear {
            requestMicrophonePermission()
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: currentState)
    }
    
    // MARK: - Dynamic Properties
    private var dynamicWidth: CGFloat {
        switch currentState {
        case .idle: return 80
        case .listening, .transcribing: return 360
        case .completed: return 400
        }
    }
    
    private var dynamicHeight: CGFloat {
        switch currentState {
        case .idle: return 80
        case .listening, .transcribing, .completed: return 80
        }
    }
    
    private var dynamicCornerRadius: CGFloat {
        switch currentState {
        case .idle: return 40
        case .listening, .transcribing, .completed: return 40
        }
    }
    
    // MARK: - State Views
    private var idleStateView: some View {
        ZStack {
            // Main content - centered
            Button(action: startRecording) {
                ZStack {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: "mic.fill")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(.white)
                }
            }
            .buttonStyle(.plain)
            .disabled(isProcessing)
            
            // Close button - top right corner (only visible on hover or always visible)
            VStack {
                HStack {
                    Spacer()
                    closeButton
                        .padding(.top, 6)
                        .padding(.trailing, 6)
                }
                Spacer()
            }
        }
    }
    
    private var listeningStateView: some View {
        HStack(spacing: 0) {
            // Close button on far left
            closeButton
                .padding(.leading, 16)
            
            // Stop button
            Button(action: stopRecording) {
                ZStack {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 48, height: 48)
                    
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.white)
                        .frame(width: 14, height: 14)
                }
            }
            .buttonStyle(.plain)
            .padding(.leading, 12)
            
            // Audio waveform in the center
            HStack {
                Spacer()
                AudioVisualizer(isRecording: $appState.audioRecorder.isRecording)
                    .frame(width: 140, height: 32)
                Spacer()
            }
            
            // Status indicator and text
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.red)
                    .frame(width: 6, height: 6)
                
                Text("Listening...")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
            }
            .padding(.trailing, 16)
        }
        .frame(maxWidth: .infinity)
    }
    
    private var transcribingStateView: some View {
        HStack(spacing: 0) {
            // Close button on far left
            closeButton
                .padding(.leading, 16)
            
            // Disabled stop button (visual consistency)
            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.6))
                    .frame(width: 48, height: 48)
                
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white)
                    .frame(width: 14, height: 14)
            }
            .padding(.leading, 12)
            
            // Faded audio waveform in the center
            HStack {
                Spacer()
                AudioVisualizer(isRecording: $appState.audioRecorder.isRecording)
                    .frame(width: 140, height: 32)
                    .opacity(0.6)
                Spacer()
            }
            
            // Status indicator and text
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 6, height: 6)
                
                Text("Transcribing...")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
            }
            .padding(.trailing, 16)
        }
        .frame(maxWidth: .infinity)
    }
    
    private var completedStateView: some View {
        HStack(spacing: 0) {
            // Close button on far left
            closeButton
                .padding(.leading, 16)
            
            // Green microphone button
            ZStack {
                Circle()
                    .fill(Color.green)
                    .frame(width: 48, height: 48)
                
                Image(systemName: "mic.fill")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white)
            }
            .padding(.leading, 12)
            
            // Status text in center
            HStack {
                Spacer()
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 6, height: 6)
                    
                    Text("Copied to clipboard")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
                }
                Spacer()
            }
            
            // Action buttons on the right
            HStack(spacing: 6) {
                Button("Copy") {
                    copyToClipboard()
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.9))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .buttonStyle(.plain)
                
                Button("Record") {
                    startNewRecording()
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.9))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .buttonStyle(.plain)
            }
            .padding(.trailing, 16)
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Helper Views
    private var closeButton: some View {
        Button(action: closeWindow) {
            Image(systemName: "xmark")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white.opacity(0.6))
                .frame(width: 20, height: 20)
                .background(Color.white.opacity(0.08))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            // Could add hover effect here if needed
        }
    }
    
    // MARK: - Actions
    private func startRecording() {
        guard !isProcessing else { return }
        
        print("🎬 FloatingRecorderView: Starting recording...")
        errorMessage = nil
        currentState = .listening
        recordingStartTime = Date()
        appState.audioRecorder.startRecording()
        
        print("🎬 FloatingRecorderView: Recording started, isRecording = \(appState.audioRecorder.isRecording)")
    }
    
    private func stopRecording() {
        print("🎬 FloatingRecorderView: Stopping recording...")
        
        guard let audioURL = appState.audioRecorder.stopRecording() else {
            print("🎬 FloatingRecorderView: ❌ Failed to stop recording")
            errorMessage = "Failed to stop recording"
            currentState = .idle
            return
        }
        
        print("🎬 FloatingRecorderView: Recording stopped successfully, transitioning to transcribing...")
        currentState = .transcribing
        isProcessing = true
        
        Task {
            do {
                let transcription = try await appState.transcriber.transcribeAudio(at: audioURL)
                
                await MainActor.run {
                    transcribedText = transcription
                    
                    // Add to history
                    let duration = recordingStartTime.map { Date().timeIntervalSince($0) }
                    let item = TranscriptionItem(id: UUID(), text: transcription, timestamp: Date(), duration: duration)
                    appState.history.addTranscription(item)
                    
                    // Auto-paste the transcription
                    appState.transcriber.pasteText(transcription)
                    
                    // Save to file if needed
                    saveTranscriptionToFile(transcription)
                    
                    currentState = .completed
                    isProcessing = false
                    
                    // Auto-hide after 5 seconds (give user time to see buttons)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                        if currentState == .completed {
                            hideWindow()
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Transcription failed: \(error.localizedDescription)"
                    currentState = .idle
                    isProcessing = false
                    
                    // Auto-hide on error after 2 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        hideWindow()
                    }
                }
            }
        }
    }
    
    private func copyToClipboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(transcribedText, forType: .string)
    }
    
    private func startNewRecording() {
        currentState = .idle
        transcribedText = ""
        errorMessage = nil
        
        // Small delay then start new recording
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            startRecording()
        }
    }
    
    private func hideWindow() {
        currentState = .idle
        transcribedText = ""
        errorMessage = nil
        willAutoPaste = false
        
        // Notify AppDelegate to hide the window
        NotificationCenter.default.post(name: NSNotification.Name("HideFloatingRecorder"), object: nil)
    }
    
    private func closeWindow() {
        currentState = .idle
        transcribedText = ""
        errorMessage = nil
        willAutoPaste = false
        
        // Notify AppDelegate to close the window completely
        NotificationCenter.default.post(name: NSNotification.Name("CloseFloatingRecorder"), object: nil)
    }
    
    private func checkAutoPasteStatus() {
        // Check if there's an active text field that we can paste to
        willAutoPaste = appState.transcriber.canAutoPaste()
    }
    
    private func requestMicrophonePermission() {
        appState.audioRecorder.requestMicrophonePermission { granted in
            if !granted {
                errorMessage = "Microphone access is required"
            }
        }
    }
    
    private func saveTranscriptionToFile(_ transcription: String) {
        let timestamp = DateFormatter.filenameSafe.string(from: Date())
        let filename = "transcription_\(timestamp).txt"
        let fileURL = appState.preferences.outputSaveLocation.appendingPathComponent(filename)
        
        do {
            // Create directory if it doesn't exist
            try FileManager.default.createDirectory(
                at: appState.preferences.outputSaveLocation,
                withIntermediateDirectories: true,
                attributes: nil
            )
            
            try transcription.write(to: fileURL, atomically: true, encoding: .utf8)
        } catch {
            print("Failed to save transcription to file: \(error)")
        }
    }
}

// MARK: - Extensions
extension DateFormatter {
    static let filenameSafe: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return formatter
    }()
} 