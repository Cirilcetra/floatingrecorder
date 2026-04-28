import SwiftUI
import AVFoundation
import AppKit

struct OnboardingView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var preferences: AppPreferences
    @EnvironmentObject private var models: ModelManager

    @Binding var isPresented: Bool
    @State private var step: Step = .welcome

    @State private var micStatus: AVAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .audio)
    @State private var accessibilityTrusted: Bool = AccessibilityPermission.isTrusted
    @State private var userClickedOpenSettings: Bool = false
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    enum Step: Int, CaseIterable {
        case welcome, microphone, accessibility, model, ready
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 36)
                .padding(.vertical, 24)
            Divider()
            footer
        }
        .frame(width: 560, height: 440)
        .onReceive(timer) { _ in
            micStatus = AVCaptureDevice.authorizationStatus(for: .audio)
            accessibilityTrusted = AccessibilityPermission.isTrusted
        }
        .onChange(of: step) { _, newStep in
            if newStep == .accessibility {
                // One optional system prompt per cold launch; opening Settings is the main path.
                _ = AccessibilityPermission.requestPromptThrottled()
            }
        }
    }

    // MARK: - Header / footer

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 22))
                .foregroundStyle(.blue)
            Text("Welcome to FloatingRecorder")
                .font(.headline)
            Spacer()
            HStack(spacing: 6) {
                ForEach(Step.allCases, id: \.rawValue) { s in
                    Circle()
                        .fill(s.rawValue <= step.rawValue ? Color.blue : Color.secondary.opacity(0.3))
                        .frame(width: 7, height: 7)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private var footer: some View {
        HStack {
            if step != .welcome {
                Button("Back") { goBack() }
                    .buttonStyle(.bordered)
            }
            Spacer()
            Button(primaryActionTitle, action: primaryAction)
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(!primaryActionEnabled)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        switch step {
        case .welcome:      welcomeStep
        case .microphone:   micStep
        case .accessibility: accessibilityStep
        case .model:        modelStep
        case .ready:        readyStep
        }
    }

    private var welcomeStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: "waveform")
                .font(.system(size: 60))
                .foregroundStyle(.blue)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            Text("Talk to your Mac, get text.")
                .font(.title2.weight(.semibold))
            Text("FloatingRecorder transcribes your voice locally using Whisper — fast, accurate, and private. Nothing leaves your Mac.")
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
    }

    private var micStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            stepTitle("Microphone access", icon: "mic.fill")
            Text("FloatingRecorder needs microphone access to record what you say.")
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                statusDot(ok: micStatus == .authorized)
                Text(micStatusText).font(.callout)
                Spacer()
                if micStatus != .authorized {
                    Button("Grant Access") { requestMic() }
                }
            }
            .padding(12)
            .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
            Spacer(minLength: 0)
        }
    }

    private var accessibilityStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            stepTitle("Accessibility access", icon: "keyboard")
            Text("This permission lets the global hotkey work anywhere on your Mac, and lets auto-paste drop your transcription into focused text fields.")
                .foregroundStyle(.secondary)

            Text("If you installed an older FloatingRecorder before, open the Accessibility list, remove every old “FloatingRecorder” row with the minus button, then add this app from Applications again. Otherwise macOS may keep toggling the wrong entry.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                statusDot(ok: accessibilityTrusted)
                Text(accessibilityTrusted
                     ? "Accessibility permission granted"
                     : "Accessibility permission not yet granted")
                    .font(.callout)
                Spacer()
                if !accessibilityTrusted {
                    Button("Open Settings") {
                        userClickedOpenSettings = true
                        AccessibilityPermission.openSettings()
                    }
                }
            }
            .padding(12)
            .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))

            if !accessibilityTrusted && userClickedOpenSettings {
                VStack(alignment: .leading, spacing: 10) {
                    Label {
                        Text("Important: macOS requires a relaunch")
                            .font(.callout.weight(.semibold))
                    } icon: {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }
                    Text("After you flip the **FloatingRecorder** switch ON in System Settings, click the button below. macOS caches Accessibility permission per-process, so the app must restart to detect it.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("If the window does not close within a second, click the menu bar microphone icon, choose Diagnostics, then Show Diagnostics Log. Only one copy of the app should stay open.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                    Button {
                        AccessibilityPermission.relaunchApp()
                    } label: {
                        Label("Quit & Relaunch FloatingRecorder", systemImage: "arrow.clockwise.circle.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                }
                .padding(12)
                .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            Spacer(minLength: 0)
        }
        .animation(.easeInOut(duration: 0.2), value: userClickedOpenSettings)
    }

    private var modelStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            stepTitle("Choose a speech model", icon: "cube.box")
            Text("You can change or download more models later in Preferences → Speech models.")
                .foregroundStyle(.secondary)

            ScrollView {
                VStack(spacing: 8) {
                    ForEach(models.catalog) { model in
                        ModelRow(model: model)
                            .padding(.vertical, 4)
                        Divider()
                    }
                }
            }
            .frame(maxHeight: 220)
            Spacer(minLength: 0)
        }
    }

    private var readyStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            stepTitle("You’re ready!", icon: "checkmark.seal.fill")
            Text("Press **\(preferences.hotkeyChord.displayString)** to toggle the recorder, or hold it to push-to-talk. Release to auto-paste into the focused text field (falls back to clipboard).")
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 6) {
                tip("Tap \(preferences.hotkeyChord.displayString) to start and stop recording hands-free.")
                tip("Hold \(preferences.hotkeyChord.displayString) while speaking; release to transcribe and paste.")
                tip("Open Preferences anytime from the menu-bar microphone icon.")
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: - Helpers

    private func stepTitle(_ title: String, icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).font(.system(size: 20)).foregroundStyle(.blue)
            Text(title).font(.title3.weight(.semibold))
        }
    }

    @ViewBuilder
    private func statusDot(ok: Bool) -> some View {
        Circle().fill(ok ? Color.green : Color.orange).frame(width: 10, height: 10)
    }

    private func tip(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text(text).foregroundStyle(.secondary)
        }
    }

    private var micStatusText: String {
        switch micStatus {
        case .authorized:  return "Microphone permission granted"
        case .denied:      return "Denied — open System Settings to enable"
        case .restricted:  return "Access restricted by system"
        case .notDetermined: return "Not requested yet"
        @unknown default:  return "Unknown"
        }
    }

    private var primaryActionTitle: String {
        switch step {
        case .welcome:       return "Get Started"
        case .microphone:    return micStatus == .authorized ? "Continue" : "Grant Access"
        case .accessibility: return accessibilityTrusted ? "Continue" : "Open Settings"
        case .model:         return "Continue"
        case .ready:         return "Done"
        }
    }

    private var primaryActionEnabled: Bool {
        switch step {
        case .welcome:       return true
        case .microphone:    return true
        case .accessibility: return true
        case .model:         return models.activeModel != nil
        case .ready:         return true
        }
    }

    private func primaryAction() {
        switch step {
        case .welcome:
            step = .microphone
        case .microphone:
            if micStatus == .authorized {
                step = .accessibility
            } else {
                requestMic()
            }
        case .accessibility:
            if accessibilityTrusted {
                step = .model
            } else {
                userClickedOpenSettings = true
                AccessibilityPermission.openSettings()
            }
        case .model:
            step = .ready
        case .ready:
            preferences.hasCompletedOnboarding = true
            isPresented = false
        }
    }

    private func goBack() {
        if let prev = Step(rawValue: step.rawValue - 1) {
            step = prev
        }
    }

    private func requestMic() {
        appState.audioRecorder.requestMicrophonePermission { granted in
            micStatus = AVCaptureDevice.authorizationStatus(for: .audio)
            if granted { step = .accessibility }
        }
    }
}
