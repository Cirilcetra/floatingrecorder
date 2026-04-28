import SwiftUI

struct AudioVisualizer: View {
    let isRecording: Bool
    @EnvironmentObject private var appState: AppState

    var body: some View {
        HStack(alignment: .center, spacing: 2) {
            ForEach(0..<20, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.45),
                                Color.white.opacity(0.85),
                                Color.white
                            ],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(width: 5, height: barHeight(for: index))
                    .animation(.easeOut(duration: 0.12), value: appState.audioRecorder.audioLevels)
            }
        }
        .frame(height: 30)
    }

    private func barHeight(for index: Int) -> CGFloat {
        let level = appState.audioRecorder.audioLevels[safe: index] ?? 0.0
        let clamped = max(0.0, min(1.0, level))
        let minH: CGFloat = 4
        let maxH: CGFloat = 30
        return max(minH, minH + CGFloat(clamped) * (maxH - minH))
    }
}

extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
