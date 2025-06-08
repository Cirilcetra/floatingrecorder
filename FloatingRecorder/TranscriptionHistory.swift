import Foundation

struct TranscriptionItem: Identifiable, Codable {
    let id: UUID
    let text: String
    let timestamp: Date
    let duration: TimeInterval?
    
    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: timestamp)
    }
}

class TranscriptionHistory: ObservableObject {
    @Published var items: [TranscriptionItem] = []
    
    private let userDefaults = UserDefaults.standard
    private let historyKey = "TranscriptionHistory"
    
    init() {
        loadHistory()
    }
    
    func addTranscription(_ text: String, duration: TimeInterval? = nil) {
        let item = TranscriptionItem(
            id: UUID(),
            text: text,
            timestamp: Date(),
            duration: duration
        )
        addTranscription(item)
    }
    
    func addTranscription(_ item: TranscriptionItem) {
        items.insert(item, at: 0) // Add to beginning for newest first
        
        // Keep only last 50 items to prevent unlimited growth
        if items.count > 50 {
            items = Array(items.prefix(50))
        }
        
        saveHistory()
    }
    
    func removeTranscription(_ item: TranscriptionItem) {
        print("DEBUG: Attempting to remove transcription with ID: \(item.id)")
        print("DEBUG: Items before removal: \(items.count)")
        items.removeAll { $0.id == item.id }
        print("DEBUG: Items after removal: \(items.count)")
        saveHistory()
    }
    
    func clearHistory() {
        items.removeAll()
        saveHistory()
    }
    
    private func saveHistory() {
        if let encoded = try? JSONEncoder().encode(items) {
            userDefaults.set(encoded, forKey: historyKey)
        }
    }
    
    private func loadHistory() {
        if let data = userDefaults.data(forKey: historyKey),
           let decoded = try? JSONDecoder().decode([TranscriptionItem].self, from: data) {
            items = decoded
        }
    }
} 