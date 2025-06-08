import SwiftUI
import AVFoundation

struct AudioVisualizer: View {
    @Binding var isRecording: Bool
    @EnvironmentObject private var appState: AppState
    @State private var debugCounter = 0
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 1) {
            ForEach(0..<20, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.4),
                                Color.white.opacity(0.8),
                                Color.white
                            ],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(
                        width: 6,
                        height: barHeight(for: index)
                    )
                    .animation(.easeOut(duration: 0.15), value: appState.audioRecorder.audioLevels)
            }
        }
        .frame(height: 32) // Fixed container height
        .onAppear {
            print("🎵 AudioVisualizer: View appeared")
            print("🎵 AudioVisualizer: Initial audioLevels = \(appState.audioRecorder.audioLevels)")
            print("🎵 AudioVisualizer: Initial isRecording = \(isRecording)")
        }
        .onChange(of: isRecording) { oldValue, newValue in
            print("🎵 AudioVisualizer: isRecording changed from \(oldValue) to \(newValue)")
            
            if newValue {
                print("🎵 AudioVisualizer: Recording started - should see real-time audio levels")
            } else {
                print("🎵 AudioVisualizer: Recording stopped - audio levels should fade to zero")
            }
        }
        .onChange(of: appState.audioRecorder.audioLevels) { oldValue, newValue in
            debugCounter += 1
            
            // Debug every update for better tracking
            if debugCounter % 10 == 0 { // Log every 10th update to avoid spam
                let maxLevel = newValue.max() ?? 0.0
                let avgLevel = newValue.reduce(0, +) / Float(newValue.count)
                print("🎵 AudioVisualizer: Update #\(debugCounter) - Max: \(String(format: "%.3f", maxLevel)), Avg: \(String(format: "%.3f", avgLevel))")
                print("🎵 AudioVisualizer: First 5 levels: \(newValue.prefix(5).map { String(format: "%.3f", $0) })")
            }
        }
    }
    
    private func barHeight(for index: Int) -> CGFloat {
        let level = appState.audioRecorder.audioLevels[safe: index] ?? 0.0
        
        // Ensure we have a reasonable range (0.0 to 1.0)
        let clampedLevel = max(0.0, min(1.0, level))
        
        // Calculate height: minimum 4px, maximum 32px
        let minHeight: CGFloat = 4
        let maxHeight: CGFloat = 32
        let calculatedHeight = minHeight + (CGFloat(clampedLevel) * (maxHeight - minHeight))
        
        // Add some visual feedback even when silent
        let finalHeight = max(minHeight, calculatedHeight)
        
        return finalHeight
    }
}

// Safe array subscript extension
extension Array {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
} 