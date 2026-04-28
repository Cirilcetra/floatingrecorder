import Foundation
import AVFoundation
import AppKit

final class AudioRecorder: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var audioLevels: [Float] = Array(repeating: 0.0, count: 20)

    private var audioEngine = AVAudioEngine()
    private var audioFile: AVAudioFile?
    private var recordingURL: URL?

    private let levelsQueue = DispatchQueue(label: "com.floatingrecorder.levels", qos: .userInitiated)
    private var lastLevelUpdate: CFAbsoluteTime = 0
    private let levelUpdateInterval: CFAbsoluteTime = 1.0 / 15.0

    override init() {
        super.init()
    }

    // MARK: - Public API

    func startRecording() {
        requestMicrophonePermission { [weak self] granted in
            guard let self else { return }
            if granted {
                self.startRecordingInternal()
            } else {
                DispatchQueue.main.async { self.showMicrophonePermissionAlert() }
            }
        }
    }

    @discardableResult
    func stopRecording() -> URL? {
        guard isRecording else { return nil }

        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        audioFile = nil

        isRecording = false

        DispatchQueue.main.async { [weak self] in
            self?.audioLevels = Array(repeating: 0.0, count: 20)
        }

        let url = recordingURL
        recordingURL = nil
        return url
    }

    // MARK: - Internals

    private func startRecordingInternal() {
        let tempDir = FileManager.default.temporaryDirectory
        let url = tempDir.appendingPathComponent("floatingrec-\(Int(Date().timeIntervalSince1970)).wav")
        recordingURL = url

        let inputNode = audioEngine.inputNode
        inputNode.removeTap(onBus: 0)

        let recordingFormat = inputNode.outputFormat(forBus: 0)

        do {
            audioFile = try AVAudioFile(forWriting: url, settings: recordingFormat.settings)
        } catch {
            Log.audio.error("Failed to create audio file: \(error.localizedDescription)")
            return
        }

        let bufferSize: UInt32 = 4096
        inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: recordingFormat) { [weak self] buffer, _ in
            guard let self else { return }

            do {
                try self.audioFile?.write(from: buffer)
            } catch {
                Log.audio.error("Buffer write failed: \(error.localizedDescription)")
            }

            self.levelsQueue.async {
                self.processAudioBuffer(buffer)
            }
        }

        do {
            audioEngine.prepare()
            try audioEngine.start()
            DispatchQueue.main.async { self.isRecording = true }
        } catch {
            Log.audio.error("Failed to start audio engine: \(error.localizedDescription)")
            inputNode.removeTap(onBus: 0)
        }
    }

    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        let now = CFAbsoluteTimeGetCurrent()
        guard now - lastLevelUpdate >= levelUpdateInterval else { return }
        lastLevelUpdate = now

        guard let channelData = buffer.floatChannelData else { return }
        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else { return }

        let ptr = UnsafeBufferPointer(start: channelData[0], count: frameLength)

        let chunkSize = max(1, frameLength / 20)
        var newLevels = [Float](repeating: 0, count: 20)

        for i in 0..<20 {
            let start = i * chunkSize
            let end = min(start + chunkSize, frameLength)
            guard start < frameLength else { break }

            var sumSquares: Float = 0
            for j in start..<end {
                let sample = ptr[j]
                sumSquares += sample * sample
            }
            let rms = sqrt(sumSquares / Float(end - start))
            let level = min(rms * 50.0, 1.0)
            newLevels[i] = max(0, min(1, level))
        }

        DispatchQueue.main.async { [weak self] in
            self?.audioLevels = newLevels
        }
    }

    private func showMicrophonePermissionAlert() {
        let alert = NSAlert()
        alert.messageText = "Microphone Permission Required"
        alert.informativeText = """
        FloatingRecorder needs access to your microphone to record audio.

        Please go to System Settings > Privacy & Security > Microphone and enable access for FloatingRecorder.
        """
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn,
           let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - Permissions

extension AudioRecorder {
    func requestMicrophonePermission(completion: @escaping (Bool) -> Void) {
        func doRequest() {
            switch AVCaptureDevice.authorizationStatus(for: .audio) {
            case .authorized:
                completion(true)
            case .notDetermined:
                AVCaptureDevice.requestAccess(for: .audio) { granted in
                    DispatchQueue.main.async { completion(granted) }
                }
            case .denied, .restricted:
                completion(false)
            @unknown default:
                completion(false)
            }
        }

        if Thread.isMainThread {
            doRequest()
        } else {
            DispatchQueue.main.async { doRequest() }
        }
    }
}
