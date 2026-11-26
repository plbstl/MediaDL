import Foundation
import WhisperKit

struct SpeechSpan: Sendable {
    let start: Double
    let text: String
}

@MainActor
final class HindiSpeechTranscriber {
    static let modelID = "large-v3-v20240930_626MB"

    private let fileManager = FileManager.default
    private static let tokenizerFiles = ["config.json", "tokenizer_config.json", "tokenizer.json"]
    private let defaultsKey = "hindiWhisperModelFolder"

    func isModelInstalled() -> Bool {
        isModelInstalled(variant: Self.modelID)
    }

    func isModelInstalled(variant: String) -> Bool {
        guard let folder = storedModelFolder(for: variant) else { return false }
        return Self.isCompatibleModelFolder(folder) && Self.tokenizerFiles.allSatisfy {
            fileManager.fileExists(atPath: Self.tokenizerDirectory(for: variant).appendingPathComponent($0).path)
        }
    }

    private var storedModelFolder: URL? {
        guard let path = UserDefaults.standard.string(forKey: defaultsKey) else { return nil }
        return URL(fileURLWithPath: path, isDirectory: true)
    }

    private func storedModelFolder(for variant: String) -> URL? {
        guard let path = UserDefaults.standard.string(forKey: Self.defaultsKey(for: variant)) else {
            return variant == Self.modelID ? storedModelFolder : nil
        }
        return URL(fileURLWithPath: path, isDirectory: true)
    }

    func downloadModel() async throws {
        try await downloadModel(variant: Self.modelID)
    }

    func downloadModel(variant: String) async throws {
        let folder = try await WhisperKit.download(
            variant: variant,
            downloadBase: Self.downloadBase
        )
        guard Self.isCompatibleModelFolder(folder) else { throw ModelStoreError.incompleteDownload }
        try await prepareTokenizer(for: variant)
        UserDefaults.standard.set(folder.path, forKey: Self.defaultsKey(for: variant))
    }

    func deleteModel() throws {
        try deleteModel(variant: Self.modelID)
    }

    func deleteModel(variant: String) throws {
        guard let folder = storedModelFolder(for: variant) else { return }
        if fileManager.fileExists(atPath: folder.path) { try fileManager.removeItem(at: folder) }
        UserDefaults.standard.removeObject(forKey: Self.defaultsKey(for: variant))
        if variant == Self.modelID { UserDefaults.standard.removeObject(forKey: defaultsKey) }
    }

    func importModel(from source: URL, variant: String) async throws {
        guard Self.isCompatibleModelFolder(source) else { throw ModelStoreError.incompatibleModel }
        let importedRoot = Self.downloadBase.appendingPathComponent("imported", isDirectory: true)
        try fileManager.createDirectory(at: importedRoot, withIntermediateDirectories: true)
        let destination = importedRoot.appendingPathComponent(Self.safeFolderName(for: variant), isDirectory: true)
        let staging = importedRoot.appendingPathComponent("staging-\(UUID().uuidString)", isDirectory: true)
        let backup = importedRoot.appendingPathComponent("backup-\(UUID().uuidString)", isDirectory: true)
        try fileManager.copyItem(at: source, to: staging)
        let hadModel = fileManager.fileExists(atPath: destination.path)
        do {
            guard Self.isCompatibleModelFolder(staging) else { throw ModelStoreError.incompatibleModel }
            try await prepareTokenizer(for: variant, importFolder: staging)
            if hadModel { try fileManager.moveItem(at: destination, to: backup) }
            try fileManager.moveItem(at: staging, to: destination)
            UserDefaults.standard.set(destination.path, forKey: Self.defaultsKey(for: variant))
            if hadModel { try? fileManager.removeItem(at: backup) }
        } catch {
            try? fileManager.removeItem(at: staging)
            if hadModel, !fileManager.fileExists(atPath: destination.path) {
                try? fileManager.moveItem(at: backup, to: destination)
            }
            throw error
        }
    }

    func transcribe(audioURL: URL) async throws -> [SpeechSpan] {
        try await transcribe(audioURL: audioURL, variant: Self.modelID, language: "hi")
    }

    func transcribe(audioURL: URL, variant: String, language: String? = nil) async throws -> [SpeechSpan] {
        guard let folder = storedModelFolder(for: variant), isModelInstalled(variant: variant) else {
            throw ModelStoreError.hindiModelMissing
        }

        let whisperKit = try await WhisperKit(
            model: variant,
            modelFolder: folder.path,
            tokenizerFolder: Self.downloadBase,
            download: false
        )
        let options = DecodingOptions(language: language, detectLanguage: language == nil, skipSpecialTokens: true)
        let results = try await whisperKit.transcribe(audioPath: audioURL.path, decodeOptions: options)
        return results.flatMap { result in
            result.segments.compactMap { segment in
                let text = segment.text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else { return nil }
                return SpeechSpan(start: Double(segment.start), text: text)
            }
        }
    }

    private static func tokenizerRepo(for variant: String) -> String {
        if variant.contains("large-v3") { return "openai/whisper-large-v3" }
        return "openai/" + variant.replacingOccurrences(of: "openai_", with: "")
    }

    private static func tokenizerDirectory(for variant: String) -> URL {
        downloadBase.appendingPathComponent("models/" + tokenizerRepo(for: variant), isDirectory: true)
    }

    private static func defaultsKey(for variant: String) -> String {
        "hindiWhisperModelFolder.\(variant)"
    }

    private static func safeFolderName(for variant: String) -> String {
        variant.replacingOccurrences(of: "/", with: "_")
    }

    private static func isCompatibleModelFolder(_ folder: URL) -> Bool {
        let requiredModels = ["MelSpectrogram", "AudioEncoder", "TextDecoder"]
        return requiredModels.allSatisfy { name in
            ["mlmodelc", "mlpackage"].contains { ext in
                fileManagerForValidation.fileExists(atPath: folder.appendingPathComponent("\(name).\(ext)").path)
            }
        }
    }

    private static var fileManagerForValidation: FileManager { .default }

    private func prepareTokenizer(for variant: String, importFolder: URL? = nil) async throws {
        let directory = Self.tokenizerDirectory(for: variant)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let remote = URL(string: "https://huggingface.co")!
            .appendingPathComponent(Self.tokenizerRepo(for: variant))
            .appendingPathComponent("resolve/main")
        for filename in Self.tokenizerFiles {
            let destination = directory.appendingPathComponent(filename)
            if fileManager.fileExists(atPath: destination.path) { continue }
            let data: Data
            if let local = importFolder?.appendingPathComponent(filename), fileManager.fileExists(atPath: local.path) {
                data = try Data(contentsOf: local)
            } else {
                let (downloaded, response) = try await URLSession.shared.data(from: remote.appendingPathComponent(filename))
                guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                    throw ModelStoreError.incompleteDownload
                }
                data = downloaded
            }
            guard (try JSONSerialization.jsonObject(with: data)) is [String: Any] else {
                throw ModelStoreError.incompleteDownload
            }
            try data.write(to: destination, options: .atomic)
        }
    }

    private static var downloadBase: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return appSupport.appendingPathComponent("MediaDLSpeech/WhisperKit", isDirectory: true)
    }
}
