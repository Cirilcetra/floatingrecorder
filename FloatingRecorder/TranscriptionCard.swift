import SwiftUI

struct TranscriptionCard: View {
    let item: TranscriptionItem
    let onCopy: () -> Void
    let onDelete: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.formattedTimestamp)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    if Calendar.current.isDateInToday(item.timestamp) {
                        Text("Today")
                            .font(.caption2)
                            .foregroundColor(.blue)
                    } else {
                        Text(item.formattedDate)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                HStack(spacing: 8) {
                    Button(action: onCopy) {
                        Image(systemName: "doc.on.clipboard")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(.plain)
                    .opacity(isHovered ? 1.0 : 0.7)
                    
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                    .opacity(isHovered ? 1.0 : 0.7)
                }
            }
            
            Text(item.text)
                .font(.system(size: 12, weight: .medium))
                .lineLimit(3)
                .multilineTextAlignment(.leading)
                .textSelection(.enabled)
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
        }
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
} 