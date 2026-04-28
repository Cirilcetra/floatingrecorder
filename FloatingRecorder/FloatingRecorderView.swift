import SwiftUI
import AppKit

struct FloatingRecorderView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var preferences: AppPreferences

    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var transcribedText: String = ""
    @State private var recordingStartTime: Date?
    @State private var currentState: RecordingState = .idle
    @State private var deliveryHint: String = "Copied to clipboard"

    enum RecordingState {
        case idle
        case listening
        case transcribing
        case completed
        case error
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: dynamicCornerRadius)
                .fill(Color.black.opacity(0.92))
                .overlay {
                    RoundedRectangle(cornerRadius: dynamicCornerRadius)
                        .fill(.ultraThinMaterial)
                        .opacity(0.15)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: dynamicCornerRadius)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                }

            Group {
                switch currentState {
                case .idle:         idleStateView
                case .listening:    listeningStateView
                case .transcribing: transcribingStateView
                case .completed:    completedStateView
                case .error:        errorStateView
                }
            }
            .transition(.opacity.combined(with: .scale(scale: 0.96)))
        }
        .frame(width: dynamicWidth, height: dynamicHeight)
        .animation(.spring(response: 0.45, dampingFraction: 0.78), value: currentState)
        .onReceive(NotificationCenter.default.publisher(for: .showFloating)) { _ in
            if currentState == .idle {
                startRecording()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .hideFloating)) { _ in
            if currentState == .listening {
                stopRecording()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .startPushToTalk)) { _ in
            if currentState == .idle {
                startRecording()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .stopPushToTalk)) { _ in
            if currentState == .listening {
                stopRecording()
            }
        }
        .onAppear {
            appState.audioRecorder.requestMicrophonePermission { granted in
                if !granted { errorMessage = "Microphone access is required" }
            }
        }
    }

    // MARK: - Dimensions

    private var dynamicWidth: CGFloat {
        switch currentState {
        case .idle: return 80
        case .listening, .transcribing: return 360
        case .completed: return 400
        case .error: return 340
        }
    }

    private var dynamicHeight: CGFloat { currentState == .idle ? 80 : 80 }
    private var dynamicCornerRadius: CGFloat { 40 }

    // MARK: - State views

    private var idleStateView: some View {
        ZStack {
            Button(action: startRecording) {
                ZStack {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 56, height: 56)
                    Image(systemName: "mic.fill")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(.white)
                }
            }
            .buttonStyle(.plain)
            .disabled(isProcessing)

            VStack {
                HStack {
                    Spacer()
                    closeButton.padding(.top, 6).padding(.trailing, 6)
                }
                Spacer()
            }
        }
    }

    private var listeningStateView: some View {
        HStack(spacing: 0) {
            closeButton.padding(.leading, 14)

            Button(action: stopRecording) {
                ZStack {
                    Circle().fill(Color.red).frame(width: 44, height: 44)
                    RoundedRectangle(cornerRadius: 2).fill(Color.white).frame(width: 12, height: 12)
                }
            }
            .buttonStyle(.plain)
            .padding(.leading, 10)

            HStack {
                Spacer()
                AudioVisualizer(isRecording: appState.audioRecorder.isRecording)
                    .frame(width: 140, height: 30)
                Spacer()
            }

            HStack(spacing: 6) {
                Circle().fill(Color.red).frame(width: 6, height: 6)
                Text(appState.isPushToTalk ? "Hold to talk" : "Listening")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white)
            }
            .padding(.trailing, 14)
        }
    }

    private var transcribingStateView: some View {
        HStack(spacing: 0) {
            closeButton.padding(.leading, 14)

            ZStack {
                Circle().fill(Color.orange.opacity(0.85)).frame(width: 44, height: 44)
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(.white)
                    .scaleEffect(0.8)
            }
            .padding(.leading, 10)

            HStack {
                Spacer()
                AudioVisualizer(isRecording: appState.audioRecorder.isRecording)
                    .frame(width: 140, height: 30)
                    .opacity(0.5)
                Spacer()
            }

            HStack(spacing: 6) {
                Circle().fill(Color.orange).frame(width: 6, height: 6)
                Text("Transcribing")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white)
            }
            .padding(.trailing, 14)
        }
    }

    private var completedStateView: some View {
        HStack(spacing: 0) {
            closeButton.padding(.leading, 14)

            ZStack {
                Circle().fill(Color.green).frame(width: 44, height: 44)
                Image(systemName: "checkmark")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .padding(.leading, 10)

            HStack {
                Spacer()
                HStack(spacing: 6) {
                    Circle().fill(Color.green).frame(width: 6, height: 6)
                    Text(deliveryHint)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }
                Spacer()
            }

            HStack(spacing: 6) {
                pillButton("Copy", action: copyToClipboard)
                pillButton("Record", action: startNewRecording)
            }
            .padding(.trailing, 14)
        }
    }

    private var errorStateView: some View {
        HStack(spacing: 12) {
            closeButton.padding(.leading, 14)
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 18))
                .foregroundStyle(.orange)
            Text(errorMessage ?? "Something went wrong")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white)
                .lineLimit(2)
                .padding(.trailing, 14)
            Spacer(minLength: 0)
        }
    }

    // MARK: - Helpers

    private func pillButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.white.opacity(0.95))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .buttonStyle(.plain)
    }

    private var closeButton: some View {
        Button(action: closeWindow) {
            Image(systemName: "xmark")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white.opacity(0.65))
                .frame(width: 20, height: 20)
                .background(Color.white.opacity(0.08))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private func startRecording() {
        guard !isProcessing else { return }
        errorMessage = nil
        currentState = .listening
        recordingStartTime = Date()
        appState.audioRecorder.startRecording()
    }

    private func stopRecording() {
        guard let audioURL = appState.audioRecorder.stopRecording() else {
            errorMessage = "Failed to stop recording"
            currentState = .error
            scheduleAutoHide(after: 2)
            return
        }

        currentState = .transcribing
        isProcessing = true

        let previousApp = appState.lastActiveApp
        let autoPaste = preferences.autoPasteEnabled

        Task {
            do {
                let transcription = try await appState.transcriber.transcribeAudio(at: audioURL)

                await MainActor.run {
                    transcribedText = transcription

                    let duration = recordingStartTime.map { Date().timeIntervalSince($0) }
                    if !transcription.isEmpty {
                        let item = TranscriptionItem(id: UUID(), text: transcription, timestamp: Date(), duration: duration)
                        appState.history.addTranscription(item)
                        saveTranscriptionToFile(transcription)

                        let accepts = appState.transcriber.focusedElementAcceptsText(in: previousApp)
                        appState.transcriber.deliverText(
                            transcription,
                            previousApp: previousApp,
                            autoPasteEnabled: autoPaste
                        )
                        deliveryHint = (autoPaste && accepts)
                            ? "Pasted to \(previousApp?.localizedName ?? "app")"
                            : "Copied to clipboard"
                    } else {
                        deliveryHint = "No speech detected"
                    }

                    currentState = .completed
                    isProcessing = false
                    try? FileManager.default.removeItem(at: audioURL)
                    scheduleAutoHide(after: 3.5)
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    currentState = .error
                    isProcessing = false
                    try? FileManager.default.removeItem(at: audioURL)
                    scheduleAutoHide(after: 2.5)
                }
            }
        }
    }

    private func scheduleAutoHide(after seconds: TimeInterval) {
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) {
            if currentState == .completed || currentState == .error {
                hideWindow()
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { startRecording() }
    }

    private func hideWindow() {
        currentState = .idle
        transcribedText = ""
        errorMessage = nil
        NotificationCenter.default.post(name: .hideFloating, object: nil)
    }

    private func closeWindow() {
        currentState = .idle
        transcribedText = ""
        errorMessage = nil
        NotificationCenter.default.post(name: .closeFloating, object: nil)
    }

    private func saveTranscriptionToFile(_ transcription: String) {
        let timestamp = DateFormatter.filenameSafe.string(from: Date())
        let filename = "transcription_\(timestamp).txt"
        let folder = appState.preferences.outputSaveLocation
        let fileURL = folder.appendingPathComponent(filename)

        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try transcription.write(to: fileURL, atomically: true, encoding: .utf8)
        } catch {
            Log.ui.error("Save transcription failed: \(error.localizedDescription)")
        }
    }
}

extension DateFormatter {
    static let filenameSafe: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return f
    }()
}
