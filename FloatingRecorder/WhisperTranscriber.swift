import Foundation
import CoreGraphics
import AppKit

class WhisperTranscriber: ObservableObject {
    @Published var isTranscribing = false
    private let whisperPath: String
    private let modelPath: String
    
    init() {
        // Get paths to bundled whisper executable and model
        let bundle = Bundle.main
        
        // Path to bundled whisper executable
        whisperPath = bundle.path(forResource: "whisper", ofType: nil, inDirectory: "whisper") ?? ""
        
        // Path to bundled model
        modelPath = bundle.path(forResource: "ggml-base.en", ofType: "bin", inDirectory: "whisper") ?? ""
        
        print("🤖 WhisperTranscriber: Whisper path: \(whisperPath)")
        print("🤖 WhisperTranscriber: Model path: \(modelPath)")
        
        // Verify files exist
        setupWhisperIfNeeded()
    }
    
    private func setupWhisperIfNeeded() {
        // Check if whisper executable exists
        if whisperPath.isEmpty || !FileManager.default.fileExists(atPath: whisperPath) {
            print("❌ WhisperTranscriber: Whisper executable not found at: \(whisperPath)")
            return
        }
        
        // Check if model exists
        if modelPath.isEmpty || !FileManager.default.fileExists(atPath: modelPath) {
            print("❌ WhisperTranscriber: Model file not found at: \(modelPath)")
            return
        }
        
        // Check if whisper is executable
        if !FileManager.default.isExecutableFile(atPath: whisperPath) {
            print("❌ WhisperTranscriber: Whisper file is not executable")
            // Try to make it executable
            do {
                try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: whisperPath)
                print("✅ WhisperTranscriber: Made whisper executable")
            } catch {
                print("❌ WhisperTranscriber: Failed to make whisper executable: \(error)")
            }
        }
        
        print("✅ WhisperTranscriber: Setup complete")
    }
    
    func transcribeAudio(at url: URL) async throws -> String {
        guard !whisperPath.isEmpty && !modelPath.isEmpty else {
            throw NSError(domain: "WhisperTranscriber", code: 1, userInfo: [NSLocalizedDescriptionKey: "Whisper or model not found"])
        }
        
        await MainActor.run {
            isTranscribing = true
        }
        defer { 
            Task { @MainActor in
                isTranscribing = false
            }
        }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: whisperPath)
        
        // Set up arguments for whisper
        process.arguments = [
            "-m", modelPath,      // Model path
            "-f", url.path,       // Input file
            "-nt",               // No timestamps
            "--output-txt"       // Output format
        ]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        print("🤖 WhisperTranscriber: Starting transcription...")
        print("🤖 WhisperTranscriber: Command: \(whisperPath) \(process.arguments?.joined(separator: " ") ?? "")")
        
        try process.run()
        process.waitUntilExit()
        
        // Read any output/error
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        if !output.isEmpty {
            print("🤖 WhisperTranscriber: Process output: \(output)")
        }
        
        // Check if process was successful
        if process.terminationStatus != 0 {
            throw NSError(domain: "WhisperTranscriber", code: 2, userInfo: [NSLocalizedDescriptionKey: "Whisper process failed with status \(process.terminationStatus). Output: \(output)"])
        }
        
        // Read the output from the generated .txt file
        let outputFile = url.appendingPathExtension("txt")
        
        guard FileManager.default.fileExists(atPath: outputFile.path) else {
            throw NSError(domain: "WhisperTranscriber", code: 3, userInfo: [NSLocalizedDescriptionKey: "Output file not found at: \(outputFile.path)"])
        }
        
        let transcription = try String(contentsOf: outputFile, encoding: .utf8)
        
        // Clean up the output file
        try? FileManager.default.removeItem(at: outputFile)
        
        print("✅ WhisperTranscriber: Transcription complete")
        return transcription.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    func canAutoPaste() -> Bool {
        // Check if there's an active text field by getting focused element
        if let focusedApp = NSWorkspace.shared.frontmostApplication {
            // Exclude our own app from auto-paste detection
            if focusedApp.bundleIdentifier == Bundle.main.bundleIdentifier {
                return false
            }
            
            // For now, assume auto-paste is possible if there's a frontmost app
            // In a more sophisticated implementation, we could use Accessibility APIs
            // to check if the focused element accepts text input
            return true
        }
        return false
    }
    
    func pasteText(_ text: String) {
        // First copy to clipboard
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        
        // Add small delay to ensure clipboard is set
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // Simulate Command+V to paste
            let source = CGEventSource(stateID: .hidSystemState)
            
            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)  // 'V' key
            let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
            
            keyDown?.flags = .maskCommand
            keyUp?.flags = .maskCommand
            
            keyDown?.post(tap: .cghidEventTap)
            keyUp?.post(tap: .cghidEventTap)
        }
    }
} 