import Foundation
import Combine
import CryptoKit

/// Describes a single whisper.cpp ggml model available for download.
struct WhisperModel: Identifiable, Hashable {
    let id: String              // e.g. "tiny.en"
    let displayName: String     // e.g. "Tiny (English)"
    let filename: String        // e.g. "ggml-tiny.en.bin"
    let approximateMB: Int
    let downloadURL: URL
    let notes: String

    /// Optional expected SHA-256 (hex). When present, downloads are verified.
    let sha256: String?
}

enum ModelState: Equatable {
    case notInstalled
    case installed
    case downloading(progress: Double)
    case verifying
    case failed(String)
}

final class ModelManager: ObservableObject {
    @Published private(set) var states: [String: ModelState] = [:]

    let catalog: [WhisperModel]
    let storageDirectory: URL

    private unowned let preferences: AppPreferences
    private var downloadTasks: [String: URLSessionDownloadTask] = [:]
    private var progressObservations: [String: NSKeyValueObservation] = [:]

    init(preferences: AppPreferences) {
        self.preferences = preferences

        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = appSupport.appendingPathComponent("FloatingRecorder", isDirectory: true)
            .appendingPathComponent("models", isDirectory: true)
        self.storageDirectory = dir

        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let hfBase = "https://huggingface.co/ggerganov/whisper.cpp/resolve/main"

        self.catalog = [
            WhisperModel(
                id: "tiny.en",
                displayName: "Tiny (English)",
                filename: "ggml-tiny.en.bin",
                approximateMB: 75,
                downloadURL: URL(string: "\(hfBase)/ggml-tiny.en.bin")!,
                notes: "Fastest, lowest accuracy. English only.",
                sha256: nil
            ),
            WhisperModel(
                id: "base.en",
                displayName: "Base (English)",
                filename: "ggml-base.en.bin",
                approximateMB: 142,
                downloadURL: URL(string: "\(hfBase)/ggml-base.en.bin")!,
                notes: "Good balance of speed and accuracy. English only.",
                sha256: nil
            ),
            WhisperModel(
                id: "small.en",
                displayName: "Small (English)",
                filename: "ggml-small.en.bin",
                approximateMB: 466,
                downloadURL: URL(string: "\(hfBase)/ggml-small.en.bin")!,
                notes: "Higher accuracy, slower. English only.",
                sha256: nil
            ),
            WhisperModel(
                id: "medium.en",
                displayName: "Medium (English)",
                filename: "ggml-medium.en.bin",
                approximateMB: 1533,
                downloadURL: URL(string: "\(hfBase)/ggml-medium.en.bin")!,
                notes: "Very high accuracy. 1.5 GB, slower on CPU.",
                sha256: nil
            ),
            WhisperModel(
                id: "large-v3",
                displayName: "Large v3 (Multilingual)",
                filename: "ggml-large-v3.bin",
                approximateMB: 2951,
                downloadURL: URL(string: "\(hfBase)/ggml-large-v3.bin")!,
                notes: "Best accuracy, multilingual. 2.9 GB.",
                sha256: nil
            )
        ]

        seedBundledModelIfNeeded()
        refreshAllStates()
    }

    // MARK: - Public API

    func localURL(for model: WhisperModel) -> URL {
        storageDirectory.appendingPathComponent(model.filename)
    }

    var activeModel: WhisperModel? {
        if let m = catalog.first(where: { $0.id == preferences.activeModelId }),
           isInstalled(m) {
            return m
        }
        return catalog.first(where: { isInstalled($0) })
    }

    func isInstalled(_ model: WhisperModel) -> Bool {
        let path = localURL(for: model).path
        guard FileManager.default.fileExists(atPath: path) else { return false }
        if let attrs = try? FileManager.default.attributesOfItem(atPath: path),
           let size = attrs[.size] as? Int64 {
            return size > 1_000_000 // sanity: >1 MB
        }
        return false
    }

    func setActive(_ model: WhisperModel) {
        preferences.activeModelId = model.id
    }

    func delete(_ model: WhisperModel) {
        let url = localURL(for: model)
        try? FileManager.default.removeItem(at: url)
        refreshState(for: model)
    }

    func download(_ model: WhisperModel) {
        if case .downloading = states[model.id] { return }
        states[model.id] = .downloading(progress: 0)

        let task = URLSession.shared.downloadTask(with: model.downloadURL) { [weak self] tempURL, response, error in
            guard let self else { return }

            defer {
                DispatchQueue.main.async {
                    self.progressObservations[model.id]?.invalidate()
                    self.progressObservations.removeValue(forKey: model.id)
                    self.downloadTasks.removeValue(forKey: model.id)
                }
            }

            if let error {
                DispatchQueue.main.async {
                    self.states[model.id] = .failed(error.localizedDescription)
                }
                return
            }

            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode),
                  let tempURL else {
                DispatchQueue.main.async {
                    self.states[model.id] = .failed("Server error")
                }
                return
            }

            DispatchQueue.main.async {
                self.states[model.id] = .verifying
            }

            let destination = self.localURL(for: model)
            do {
                if FileManager.default.fileExists(atPath: destination.path) {
                    try FileManager.default.removeItem(at: destination)
                }
                try FileManager.default.moveItem(at: tempURL, to: destination)
            } catch {
                DispatchQueue.main.async {
                    self.states[model.id] = .failed("Install failed: \(error.localizedDescription)")
                }
                return
            }

            if let expected = model.sha256 {
                do {
                    let actual = try Self.sha256Hex(of: destination)
                    if actual.caseInsensitiveCompare(expected) != .orderedSame {
                        try? FileManager.default.removeItem(at: destination)
                        DispatchQueue.main.async {
                            self.states[model.id] = .failed("Checksum mismatch")
                        }
                        return
                    }
                } catch {
                    DispatchQueue.main.async {
                        self.states[model.id] = .failed("Verify failed: \(error.localizedDescription)")
                    }
                    return
                }
            }

            DispatchQueue.main.async {
                self.states[model.id] = .installed
                if self.preferences.activeModelId == model.id || self.activeModel == nil {
                    self.preferences.activeModelId = model.id
                }
            }
        }

        let observation = task.progress.observe(\.fractionCompleted, options: [.new]) { [weak self] progress, _ in
            DispatchQueue.main.async {
                self?.states[model.id] = .downloading(progress: progress.fractionCompleted)
            }
        }
        progressObservations[model.id] = observation
        downloadTasks[model.id] = task
        task.resume()
    }

    func cancelDownload(_ model: WhisperModel) {
        downloadTasks[model.id]?.cancel()
        downloadTasks.removeValue(forKey: model.id)
        progressObservations[model.id]?.invalidate()
        progressObservations.removeValue(forKey: model.id)
        states[model.id] = isInstalled(model) ? .installed : .notInstalled
    }

    // MARK: - Internals

    private func seedBundledModelIfNeeded() {
        // If the user has no installed models and we ship a bundled one, copy it over.
        let anyInstalled = catalog.contains(where: { isInstalled($0) })
        guard !anyInstalled else { return }

        let candidates = ["ggml-tiny.en", "ggml-base.en"]
        for name in candidates {
            guard let bundled = Bundle.main.path(forResource: name, ofType: "bin", inDirectory: "whisper")
                    ?? Bundle.main.path(forResource: name, ofType: "bin") else {
                continue
            }
            let modelId = name.replacingOccurrences(of: "ggml-", with: "")
            guard let model = catalog.first(where: { $0.id == modelId }) else { continue }
            let dest = localURL(for: model)
            do {
                if !FileManager.default.fileExists(atPath: dest.path) {
                    try FileManager.default.copyItem(at: URL(fileURLWithPath: bundled), to: dest)
                    Log.models.info("Seeded bundled model \(modelId)")
                }
                preferences.activeModelId = modelId
                return
            } catch {
                Log.models.error("Seed failed: \(error.localizedDescription)")
            }
        }
    }

    private func refreshAllStates() {
        var new: [String: ModelState] = [:]
        for model in catalog {
            new[model.id] = isInstalled(model) ? .installed : .notInstalled
        }
        states = new
    }

    private func refreshState(for model: WhisperModel) {
        states[model.id] = isInstalled(model) ? .installed : .notInstalled
    }

    private static func sha256Hex(of url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }

        var hasher = SHA256()
        while autoreleasepool(invoking: {
            let chunk = handle.readData(ofLength: 1024 * 1024)
            if chunk.isEmpty { return false }
            hasher.update(data: chunk)
            return true
        }) {}

        let digest = hasher.finalize()
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
