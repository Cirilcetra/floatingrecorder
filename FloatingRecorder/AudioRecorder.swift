import Foundation
import AVFoundation
import AppKit

class AudioRecorder: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var audioLevels: [Float] = Array(repeating: 0.0, count: 20)
    
    private var audioEngine = AVAudioEngine()
    private var audioFile: AVAudioFile?
    private var recordingURL: URL?
    private var isMonitoring = false
    
    override init() {
        super.init()
        setupAudioEngine()
    }
    
    private func setupAudioEngine() {
        print("🎤 AudioRecorder: Setting up audio engine for macOS...")
        // No need for AVAudioSession on macOS - it's handled automatically
    }
    
    func startRecording() {
        print("🎤 AudioRecorder: Starting recording with AVAudioEngine...")
        
        // Request microphone permission first
        requestMicrophonePermission { [weak self] granted in
            if granted {
                print("🎤 AudioRecorder: ✅ Microphone permission granted")
                self?.startRecordingInternal()
            } else {
                print("🎤 AudioRecorder: ❌ Microphone permission denied")
                DispatchQueue.main.async {
                    // Show alert to user about microphone permission
                    self?.showMicrophonePermissionAlert()
                }
            }
        }
    }
    
    private func startRecordingInternal() {
        // Create recording URL
        recordingURL = getDocumentsDirectory().appendingPathComponent("recording-\(Date().timeIntervalSince1970).wav")
        
        guard let recordingURL = recordingURL else {
            print("🎤 AudioRecorder: ❌ Failed to create recording URL")
            return
        }
        
        let inputNode = audioEngine.inputNode
        
        // Remove any existing taps first
        inputNode.removeTap(onBus: 0)
        
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        print("🎤 AudioRecorder: Input format: \(recordingFormat)")
        
        // Create audio file for recording
        do {
            audioFile = try AVAudioFile(forWriting: recordingURL, settings: recordingFormat.settings)
            print("🎤 AudioRecorder: Audio file created at \(recordingURL)")
        } catch {
            print("🎤 AudioRecorder: ❌ Failed to create audio file: \(error)")
            return
        }
        
        // Install tap for both recording and monitoring
        let bufferSize: UInt32 = 4096
        print("🎤 AudioRecorder: Installing tap with buffer size \(bufferSize)")
        
        inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: recordingFormat) { [weak self] buffer, time in
            print("🎤 AudioRecorder: 📊 Audio buffer received - frameLength: \(buffer.frameLength)")
            
            // Write to file for recording
            do {
                try self?.audioFile?.write(from: buffer)
            } catch {
                print("🎤 AudioRecorder: ❌ Failed to write audio buffer: \(error)")
            }
            
            // Process for real-time visualization
            self?.processAudioBuffer(buffer)
        }
        
        // Prepare and start the audio engine
        do {
            audioEngine.prepare()
            print("🎤 AudioRecorder: Audio engine prepared")
            
            try audioEngine.start()
            print("🎤 AudioRecorder: Audio engine started")
            
            DispatchQueue.main.async {
                self.isRecording = true
                self.isMonitoring = true
                print("🎤 AudioRecorder: ✅ Recording and monitoring started successfully")
            }
        } catch {
            print("🎤 AudioRecorder: ❌ Failed to start audio engine: \(error)")
            inputNode.removeTap(onBus: 0)
        }
    }
    
    func stopRecording() -> URL? {
        print("🎤 AudioRecorder: Stopping recording...")
        
        guard isRecording else {
            print("🎤 AudioRecorder: ⚠️ Not currently recording")
            return nil
        }
        
        // Stop the audio engine and remove tap
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        
        // Close the audio file
        audioFile = nil
        
        // Reset state
        isRecording = false
        isMonitoring = false
        
        // Clear audio levels on main thread
        DispatchQueue.main.async { [weak self] in
            self?.audioLevels = Array(repeating: 0.0, count: 20)
        }
        
        let url = recordingURL
        recordingURL = nil
        
        print("🎤 AudioRecorder: ✅ Recording stopped, file saved to: \(url?.absoluteString ?? "unknown")")
        return url
    }
    
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        print("🎤 AudioRecorder: 🔊 Processing audio buffer...")
        
        guard let channelData = buffer.floatChannelData else { 
            print("🎤 AudioRecorder: ⚠️ No channel data in buffer")
            return 
        }
        
        let frameLength = Int(buffer.frameLength)
        print("🎤 AudioRecorder: Frame length: \(frameLength)")
        
        let channelDataArray = Array(UnsafeBufferPointer(start: channelData[0], count: frameLength))
        
        guard !channelDataArray.isEmpty else {
            print("🎤 AudioRecorder: ⚠️ Empty channel data array")
            return
        }
        
        // Calculate overall RMS for debugging
        let overallRMS = sqrt(channelDataArray.map { $0 * $0 }.reduce(0, +) / Float(frameLength))
        print("🎤 AudioRecorder: Overall RMS: \(overallRMS)")
        
        // Create frequency-like visualization by processing chunks of the buffer
        let chunkSize = max(1, frameLength / 20)
        var newLevels: [Float] = []
        
        for i in 0..<20 {
            let startIndex = i * chunkSize
            let endIndex = min(startIndex + chunkSize, frameLength)
            
            if startIndex < frameLength {
                let chunk = Array(channelDataArray[startIndex..<endIndex])
                let chunkRMS = sqrt(chunk.map { $0 * $0 }.reduce(0, +) / Float(chunk.count))
                
                // Convert to a more visible scale (0.0 to 1.0)
                let level = min(chunkRMS * 50, 1.0) // Amplify by 50x for visibility
                
                // Add some variation to make it look more like a spectrum
                let variation = Float.random(in: 0.7...1.3)
                newLevels.append(max(0.0, min(1.0, level * variation)))
            } else {
                newLevels.append(0.0)
            }
        }
        
        print("🎤 AudioRecorder: New levels calculated: \(newLevels.prefix(5))")
        
        // Update on main thread
        DispatchQueue.main.async { [weak self] in
            print("🎤 AudioRecorder: 📱 Updating audio levels on main thread")
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
        if response == .alertFirstButtonReturn {
            // Open System Settings to Privacy > Microphone
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
                NSWorkspace.shared.open(url)
            }
        }
    }
    
    private func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let transcriptionsFolder = paths[0].appendingPathComponent("FloatingRecorder Transcriptions")
        
        // Create the directory if it doesn't exist
        if !FileManager.default.fileExists(atPath: transcriptionsFolder.path) {
            do {
                try FileManager.default.createDirectory(at: transcriptionsFolder, withIntermediateDirectories: true, attributes: nil)
                print("🎤 AudioRecorder: Created Transcriptions directory at \(transcriptionsFolder.path)")
            } catch {
                print("🎤 AudioRecorder: ❌ Failed to create Transcriptions directory: \(error)")
                return paths[0] // Fallback to Documents directory if creation fails
            }
        }
        
        return transcriptionsFolder
    }
}

// Extension to handle permissions
extension AudioRecorder {
    func requestMicrophonePermission(completion: @escaping (Bool) -> Void) {
        print("🎤 AudioRecorder: Requesting microphone permission...")
        
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            print("🎤 AudioRecorder: Microphone already authorized")
            completion(true)
        case .notDetermined:
            print("🎤 AudioRecorder: Microphone permission not determined, requesting...")
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                print("🎤 AudioRecorder: Microphone permission response: \(granted)")
                DispatchQueue.main.async {
                    completion(granted)
                }
            }
        case .denied, .restricted:
            print("🎤 AudioRecorder: Microphone permission denied/restricted")
            completion(false)
        @unknown default:
            print("🎤 AudioRecorder: Unknown microphone permission status")
            completion(false)
        }
    }
} 