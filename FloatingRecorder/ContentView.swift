import SwiftUI

struct ContentView: View {
    @StateObject private var audioRecorder = AudioRecorder()
    @StateObject private var transcriber = WhisperTranscriber()
    @StateObject private var history = TranscriptionHistory()
    
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var transcribedText: String = ""
    @State private var showTranscription = false
    @State private var isExpanded = false
    @State private var recordingStartTime: Date?
    
    var body: some View {
        VStack(spacing: 0) {
            // Main control panel
            mainControlPanel
            
            // Expanded history view
            if isExpanded {
                historyPanel
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .background {
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.2), radius: 10, y: 5)
        }
        .frame(maxWidth: 320)
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: isExpanded)
        .onAppear {
            // Request microphone permission when the view appears
            audioRecorder.requestMicrophonePermission { granted in
                if !granted {
                    errorMessage = "Microphone access is required"
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ToggleRecording"))) { _ in
            if audioRecorder.isRecording {
                stopRecording()
            } else {
                startRecording()
            }
        }
    }
    
    // MARK: - Main Control Panel
    private var mainControlPanel: some View {
        VStack(spacing: 16) {
            HStack {
                // Expand/Collapse button
                Button(action: {
                    withAnimation {
                        isExpanded.toggle()
                    }
                }) {
                    Image(systemName: isExpanded ? "chevron.down" : "list.bullet")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(.ultraThinMaterial))
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                // Record button with modern styling
                Button(action: {
                    if audioRecorder.isRecording {
                        stopRecording()
                    } else {
                        startRecording()
                    }
                }) {
                    ZStack {
                        Circle()
                            .fill(
                                audioRecorder.isRecording ? 
                                    LinearGradient(colors: [.red, .orange], startPoint: .topLeading, endPoint: .bottomTrailing) :
                                    LinearGradient(colors: [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                            .frame(width: 60, height: 60)
                            .scaleEffect(audioRecorder.isRecording ? 1.1 : 1.0)
                            .animation(.easeInOut(duration: 0.3), value: audioRecorder.isRecording)
                        
                        Image(systemName: audioRecorder.isRecording ? "stop.fill" : "mic.fill")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundColor(.white)
                    }
                }
                .buttonStyle(.plain)
                .disabled(isProcessing)
                
                Spacer()
                
                // Processing indicator or action buttons
                if isProcessing {
                    ProgressView()
                        .scaleEffect(0.8)
                        .frame(width: 30, height: 30)
                } else {
                    Button(action: {
                        // Settings or additional actions
                    }) {
                        Image(systemName: "gear")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.primary)
                            .frame(width: 30, height: 30)
                            .background(Circle().fill(.ultraThinMaterial))
                    }
                    .buttonStyle(.plain)
                }
            }
            
            // Waveform visualizer
            if audioRecorder.isRecording {
                AudioVisualizer(isRecording: .constant(audioRecorder.isRecording))
                    .transition(.scale.combined(with: .opacity))
            }
            
            // Current transcription
            if showTranscription && !transcribedText.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Latest Transcription")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Button("Copy") {
                            transcriber.pasteText(transcribedText)
                        }
                        .font(.caption)
                        .buttonStyle(.plain)
                        .foregroundColor(.blue)
                    }
                    
                    Text(transcribedText)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(3)
                        .padding(12)
                        .background {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.ultraThinMaterial)
                                .overlay {
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                                }
                        }
                        .textSelection(.enabled)
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
            
            // Error message
            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(8)
                    .background {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(.red.opacity(0.1))
                    }
            }
        }
        .padding(20)
    }
    
    // MARK: - History Panel
    private var historyPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Transcription History")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                if !history.items.isEmpty {
                    Button("Clear All") {
                        history.clearHistory()
                    }
                    .font(.caption)
                    .foregroundColor(.red)
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            
            if history.items.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "waveform")
                        .font(.system(size: 30))
                        .foregroundColor(.secondary)
                    
                    Text("No transcriptions yet")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("Start recording to see your transcriptions here")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(history.items) { item in
                            TranscriptionCard(
                                item: item,
                                onCopy: {
                                    transcriber.pasteText(item.text)
                                },
                                onDelete: {
                                    history.removeTranscription(item)
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .frame(maxHeight: 200)
            }
        }
        .background {
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(Color.white.opacity(0.2))
                        .frame(height: 1)
                }
        }
    }
    
    private func startRecording() {
        errorMessage = nil
        showTranscription = false
        transcribedText = ""
        recordingStartTime = Date()
        audioRecorder.startRecording()
    }
    
    private func stopRecording() {
        guard let audioURL = audioRecorder.stopRecording() else {
            DispatchQueue.main.async {
                errorMessage = "Failed to save recording"
            }
            return
        }
        
        DispatchQueue.main.async {
            isProcessing = true
            errorMessage = nil
        }
        
        Task {
            do {
                let transcription = try await transcriber.transcribeAudio(at: audioURL)
                
                await MainActor.run {
                    isProcessing = false
                    
                    if !transcription.isEmpty {
                        transcribedText = transcription
                        showTranscription = true
                        
                        // Calculate duration
                        let duration = recordingStartTime.map { Date().timeIntervalSince($0) }
                        
                        // Add to history
                        history.addTranscription(transcription, duration: duration)
                        
                        // Automatically paste the text
                        transcriber.pasteText(transcription)
                    } else {
                        errorMessage = "No speech detected"
                    }
                }
                
                // Clean up the audio file
                try? FileManager.default.removeItem(at: audioURL)
            } catch {
                await MainActor.run {
                    isProcessing = false
                    errorMessage = "Transcription failed: \(error.localizedDescription)"
                }
                print("Transcription error: \(error)")
            }
        }
    }
}

#Preview {
    ContentView()
} 
