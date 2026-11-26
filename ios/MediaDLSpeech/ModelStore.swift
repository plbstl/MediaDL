import Foundation
import FluidAudio
import Observation

enum SpeechModelID: String, CaseIterable, Identifiable {
    case parakeetUltra
    case whisperTiny = "openai_whisper-tiny"
    case whisperBase = "openai_whisper-base"
    case whisperSmall = "openai_whisper-small"
    case whisperLargeV3Turbo = "openai_whisper-large-v3-v20240930_turbo_632MB"

    var id: String { rawValue }
    var title: String {
        switch self {
        case .parakeetUltra: "Parakeet Ultra"
        case .whisperTiny: "Whisper Tiny"
        case .whisperBase: "Whisper Base"
        case .whisperSmall: "Whisper Small"
        case .whisperLargeV3Turbo: "Whisper Large-v3 Turbo"
        }
    }
    var description: String {
        switch self {
        case .parakeetUltra: "Multilingual Parakeet speech recognition using FluidAudio Core ML assets."
        case .whisperTiny: "Multilingual Whisper with the smallest storage and memory footprint."
        case .whisperBase: "Multilingual Whisper with a small storage footprint."
        case .whisperSmall: "Multilingual Whisper with a balance of size and recognition quality."
        case .whisperLargeV3Turbo: "Multilingual Whisper Large-v3 Turbo for Hindi, Hinglish, and other languages."
        }
    }
    var sizeNote: String {
        switch self {
        case .parakeetUltra: "About 630 MB. Keep MediaDL open while downloading."
        case .whisperTiny: "About 40 MB. Keep MediaDL open while downloading."
        case .whisperBase: "About 75 MB. Keep MediaDL open while downloading."
        case .whisperSmall: "About 250 MB. Keep MediaDL open while downloading."
        case .whisperLargeV3Turbo: "About 630 MB. Keep MediaDL open while downloading."
        }
    }
}

@MainActor
@Observable
final class ModelStore {
    static let shared = ModelStore()

    private(set) var isReady = false
    private(set) var isHindiReady = false
    private(set) var isBusy = false
    var selectedModelID: String {
        didSet {
            guard SpeechModelID(rawValue: selectedModelID) != nil else {
                selectedModelID = oldValue
                return
            }
            UserDefaults.standard.set(selectedModelID, forKey: Self.selectedModelKey)
            refreshStatus()
        }
    }
    var status = "Checking model…"
    var errorMessage: String?

    private let version: AsrModelVersion = .ultra
    private let encoderPrecision: ParakeetEncoderPrecision = .int8
    private let fileManager = FileManager.default
    private let hindiTranscriber = HindiSpeechTranscriber()
    private static let selectedModelKey = "selectedSpeechModelID"

    private init() {
        let savedSelection = UserDefaults.standard.string(forKey: Self.selectedModelKey)
        selectedModelID = savedSelection.flatMap(SpeechModelID.init(rawValue:))?.rawValue ?? SpeechModelID.parakeetUltra.rawValue
        refreshStatus()
    }

    var selectedModel: SpeechModelID {
        SpeechModelID(rawValue: selectedModelID) ?? .parakeetUltra
    }

    var selectedModelIsInstalled: Bool { isSelectedModelInstalled }

    private var isSelectedModelInstalled: Bool {
        switch selectedModel {
        case .parakeetUltra: isReady
        default: hindiTranscriber.isModelInstalled(variant: selectedModel.rawValue)
        }
    }

    private var installedWhisperVariants: [String] {
        var variants = SpeechModelID.allCases
            .filter { $0 != .parakeetUltra }
            .map(\.rawValue)
            .filter { hindiTranscriber.isModelInstalled(variant: $0) }
        if hindiTranscriber.isModelInstalled(), !variants.contains(HindiSpeechTranscriber.modelID) {
            variants.append(HindiSpeechTranscriber.modelID)
        }
        return variants
    }

    private var modelDirectory: URL {
        AsrModels.defaultCacheDirectory(for: version)
    }

    func refreshStatus() {
        isReady = AsrModels.modelsExist(
            at: modelDirectory,
            version: version,
            encoderPrecision: encoderPrecision
        )
        isHindiReady = installedWhisperVariants.count > 0
        status = isSelectedModelInstalled ? "Ready for offline transcription" : "\(selectedModel.title) is not installed"
    }

    func downloadModel() async {
        guard !isBusy else { return }
        isBusy = true
        errorMessage = nil
        status = "Downloading Ultra model… Keep MediaDL open."
        defer {
            isBusy = false
            refreshStatus()
        }

        do {
            ModelHub.offlineMode = false
            _ = try await AsrModels.download(
                to: modelDirectory,
                version: version,
                encoderPrecision: encoderPrecision
            )
            guard AsrModels.modelsExist(
                at: modelDirectory,
                version: version,
                encoderPrecision: encoderPrecision
            ) else {
                throw ModelStoreError.incompleteDownload
            }
        } catch {
            errorMessage = "Download failed: \(error.localizedDescription)"
        }
    }

    func deleteModel() {
        guard !isBusy else { return }
        do {
            if fileManager.fileExists(atPath: modelDirectory.path) {
                try fileManager.removeItem(at: modelDirectory)
            }
            errorMessage = nil
            refreshStatus()
        } catch {
            errorMessage = "Could not delete the model: \(error.localizedDescription)"
        }
    }

    func downloadHindiModel() async {
        await downloadHindiModel(variant: HindiSpeechTranscriber.modelID)
    }

    func downloadHindiModel(variant: String) async {
        guard !isBusy else { return }
        isBusy = true
        errorMessage = nil
        status = "Downloading \(SpeechModelID(rawValue: variant)?.title ?? "Whisper")… Keep MediaDL open."
        defer {
            isBusy = false
            refreshStatus()
        }

        do {
            try await hindiTranscriber.downloadModel(variant: variant)
        } catch {
            errorMessage = "Hindi model download failed: \(error.localizedDescription)"
        }
    }

    func downloadSelectedModel() async {
        switch selectedModel {
        case .parakeetUltra: await downloadModel()
        default: await downloadHindiModel(variant: selectedModel.rawValue)
        }
    }

    func deleteSelectedModel() {
        switch selectedModel {
        case .parakeetUltra: deleteModel()
        default: deleteHindiModel(variant: selectedModel.rawValue)
        }
    }

    func importModel(from source: URL) async {
        guard !isBusy else { return }
        isBusy = true
        errorMessage = nil
        status = "Validating imported model…"
        defer {
            isBusy = false
            refreshStatus()
        }

        let hasAccess = source.startAccessingSecurityScopedResource()
        defer {
            if hasAccess { source.stopAccessingSecurityScopedResource() }
        }

        do {
            switch selectedModel {
            case .parakeetUltra:
                try await importParakeet(from: source)
            default:
                try await hindiTranscriber.importModel(from: source, variant: selectedModel.rawValue)
            }
            errorMessage = nil
        } catch {
            errorMessage = "Model import failed: \(error.localizedDescription)"
        }
    }

    private func importParakeet(from source: URL) async throws {
        let stagingRoot = fileManager.temporaryDirectory.appendingPathComponent("MediaDL-Parakeet-\(UUID().uuidString)", isDirectory: true)
        let staging = stagingRoot.appendingPathComponent(modelDirectory.lastPathComponent, isDirectory: true)
        defer { try? fileManager.removeItem(at: stagingRoot) }
        try fileManager.createDirectory(at: stagingRoot, withIntermediateDirectories: true)
        try fileManager.copyItem(at: source, to: staging)
        guard AsrModels.modelsExist(at: stagingRoot, version: version, encoderPrecision: encoderPrecision) else {
            throw ModelStoreError.incompatibleModel
        }

        let backup = fileManager.temporaryDirectory.appendingPathComponent("MediaDL-Parakeet-backup-\(UUID().uuidString)", isDirectory: true)
        let hadModel = fileManager.fileExists(atPath: modelDirectory.path)
        if hadModel { try fileManager.moveItem(at: modelDirectory, to: backup) }
        do {
            try fileManager.createDirectory(at: modelDirectory.deletingLastPathComponent(), withIntermediateDirectories: true)
            try fileManager.moveItem(at: staging, to: modelDirectory)
            guard AsrModels.modelsExist(at: modelDirectory, version: version, encoderPrecision: encoderPrecision) else {
                throw ModelStoreError.incompleteDownload
            }
            if hadModel { try? fileManager.removeItem(at: backup) }
        } catch {
            try? fileManager.removeItem(at: modelDirectory)
            if hadModel { try? fileManager.moveItem(at: backup, to: modelDirectory) }
            throw error
        }
        selectedModelID = SpeechModelID.parakeetUltra.rawValue
    }

    func deleteHindiModel() {
        deleteHindiModel(variant: HindiSpeechTranscriber.modelID)
    }

    func deleteHindiModel(variant: String) {
        guard !isBusy else { return }
        do {
            try hindiTranscriber.deleteModel(variant: variant)
            errorMessage = nil
            refreshStatus()
        } catch {
            errorMessage = "Could not delete the Hindi model: \(error.localizedDescription)"
        }
    }

    func transcribeSpeech(audioURL: URL, useHindiModel: Bool) async throws -> [SpeechSpan] {
        if useHindiModel {
            guard !isBusy else { throw ModelStoreError.busy }
            guard hindiTranscriber.isModelInstalled() else {
                throw ModelStoreError.hindiModelMissing
            }
            isBusy = true
            status = "Transcribing Hindi audio offline…"
            defer {
                isBusy = false
                refreshStatus()
            }
            return try await hindiTranscriber.transcribe(audioURL: audioURL)
        }
        let result = try await transcribeUltra(audioURL: audioURL)
        let words = result.text.split(whereSeparator: \.isWhitespace)
        let timings = buildWordTimings(from: result.tokenTimings ?? [])
        guard !words.isEmpty else { return [] }
        guard words.count == timings.count else { return [SpeechSpan(start: 0, text: result.text)] }

        var spans: [SpeechSpan] = []
        var start = timings[0].startTime
        var phrase: [Substring] = []
        for (word, timing) in zip(words, timings) {
            if !phrase.isEmpty, timing.startTime - start >= 3 {
                spans.append(SpeechSpan(start: start, text: phrase.joined(separator: " ")))
                start = timing.startTime
                phrase.removeAll(keepingCapacity: true)
            }
            phrase.append(word)
        }
        spans.append(SpeechSpan(start: start, text: phrase.joined(separator: " ")))
        return spans
    }

    func transcribeSpeech(audioURL: URL) async throws -> [SpeechSpan] {
        let chosenVariant: String
        if isSelectedModelInstalled {
            chosenVariant = selectedModel.rawValue
        } else if (isReady ? 1 : 0) + installedWhisperVariants.count == 1 {
            if isReady {
                selectedModelID = SpeechModelID.parakeetUltra.rawValue
                chosenVariant = SpeechModelID.parakeetUltra.rawValue
            } else {
                chosenVariant = installedWhisperVariants[0]
                if SpeechModelID(rawValue: chosenVariant) != nil { selectedModelID = chosenVariant }
            }
        } else {
            throw selectedModel == .parakeetUltra ? ModelStoreError.modelMissing : ModelStoreError.hindiModelMissing
        }
        if chosenVariant == SpeechModelID.parakeetUltra.rawValue {
            return try await transcribeSpeech(audioURL: audioURL, useHindiModel: false)
        }
        isBusy = true
        status = "Transcribing offline…"
        defer { isBusy = false; refreshStatus() }
        return try await hindiTranscriber.transcribe(audioURL: audioURL, variant: chosenVariant)
    }

    func transcribe(audioURL: URL) async throws -> String {
        try await transcribeUltra(audioURL: audioURL).text
    }

    private func transcribeUltra(audioURL: URL) async throws -> ASRResult {
        guard !isBusy else { throw ModelStoreError.busy }
        guard AsrModels.modelsExist(
            at: modelDirectory,
            version: version,
            encoderPrecision: encoderPrecision
        ) else {
            refreshStatus()
            throw ModelStoreError.modelMissing
        }

        isBusy = true
        status = "Loading offline model…"
        defer {
            isBusy = false
            refreshStatus()
        }

        do {
            let models = try await Self.loadLocalModels(from: modelDirectory)
            let manager = AsrManager(config: .default)
            try await manager.loadModels(models)
            var decoderState = try TdtDecoderState(decoderLayers: version.decoderLayers)
            status = "Transcribing offline…"
            return try await manager.transcribe(audioURL, decoderState: &decoderState)
        } catch {
            throw ModelStoreError.transcriptionFailed(error.localizedDescription)
        }
    }

    private nonisolated static func loadLocalModels(from directory: URL) async throws -> AsrModels {
        try await Task.detached(priority: .userInitiated) {
            try AsrModels.loadLocal(
                from: directory,
                version: .ultra,
                encoderPrecision: .int8
            )
        }.value
    }
}

enum ModelStoreError: LocalizedError {
    case modelMissing
    case hindiModelMissing
    case busy
    case incompleteDownload
    case incompatibleModel
    case transcriptionFailed(String)

    var errorDescription: String? {
        switch self {
        case .modelMissing:
            return "Ultra is not ready. Open MediaDL Speech and download the model first."
        case .hindiModelMissing:
            return "The Hindi model is not ready. Open MediaDL Speech and download it first."
        case .busy:
            return "MediaDL Speech is already downloading or transcribing. Try again shortly."
        case .incompleteDownload:
            return "The download did not produce a complete model. Try downloading again."
        case .incompatibleModel:
            return "This folder does not contain a supported Parakeet Ultra or Whisper model."
        case .transcriptionFailed(let reason):
            return "Transcription failed: \(reason)"
        }
    }
}
