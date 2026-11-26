import AppIntents
import Foundation
import OSLog
import UniformTypeIdentifiers

struct TranscribeAudioIntent: AppIntent {
    static let title: LocalizedStringResource = "Transcribe Audio (Offline)"
    static let description = IntentDescription("Transcribes an audio file using the downloaded on-device Ultra model.")
    static let openAppWhenRun = true
    static var supportedModes: IntentModes { .foreground(.immediate) }

    @Parameter(title: "Audio")
    var audio: IntentFile

    func perform() async throws -> some ReturnsValue<String> {
        let text = try await withLocalFile(audio, fallbackExtension: "m4a") { url in
            try await ModelStore.shared.transcribe(audioURL: url)
        }
        return .result(value: text)
    }
}

enum ReelSpeechModel: String, AppEnum {
    case selected
    case ultra
    case hindi

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Speech Model"
    static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .selected: "App Default",
        .ultra: "Parakeet Ultra",
        .hindi: "Hindi / Hinglish"
    ]
}

struct TranscribeReelIntent: AppIntent {
    static let title: LocalizedStringResource = "Transcribe Reel (Offline)"
    static let description = IntentDescription("Transcribes Reel audio and adds timed on-screen text from the video.")
    static let supportedModes: IntentModes = .foreground(.immediate)

    @Parameter(title: "Audio")
    var audio: IntentFile

    @Parameter(title: "Video", supportedContentTypes: [.movie, .mpeg4Movie])
    var video: IntentFile?

    @Parameter(title: "Speech Model", default: .selected)
    var speechModel: ReelSpeechModel

    static var parameterSummary: some ParameterSummary {
        Summary("Transcribe \(\.$audio) from \(\.$video) using \(\.$speechModel)")
    }

    func perform() async throws -> some ReturnsValue<String> {
        let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "MediaDL", category: "TranscribeReelIntent")
        do {
            if #available(iOS 27.0, *) {
                let longRunningIntent = self as any LongRunningIntent & CancellableIntent
                let text = try await longRunningIntent.performBackgroundTask {
                    try await self.transcribeReel(progress: longRunningIntent.progress, logger: logger)
                } onCancel: { reason in
                    logger.error("Transcribe Reel cancelled: \(reason.debugDescription, privacy: .private)")
                }
                return .result(value: text)
            }

            return .result(value: try await transcribeReel(progress: nil, logger: logger))
        } catch {
            logger.error("Transcribe Reel failed: \(error.localizedDescription, privacy: .private)")
            throw error
        }
    }

    private func transcribeReel(progress: Progress?, logger: Logger) async throws -> String {
        let heartbeat = progress.map { progress in
            Task {
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(10))
                    guard !Task.isCancelled else { return }
                    progress.localizedAdditionalDescription = "Still working"
                }
            }
        }
        defer { heartbeat?.cancel() }

        progress?.totalUnitCount = 2
        progress?.completedUnitCount = 0
        progress?.localizedDescription = "Transcribing audio"
        let speech = try await withLocalFile(audio, fallbackExtension: "m4a") { url in
            switch speechModel {
            case .selected:
                try await ModelStore.shared.transcribeSpeech(audioURL: url)
            case .ultra:
                try await ModelStore.shared.transcribeSpeech(audioURL: url, useHindiModel: false)
            case .hindi:
                try await ModelStore.shared.transcribeSpeech(audioURL: url, useHindiModel: true)
            }
        }
        try Task.checkCancellation()
        progress?.completedUnitCount = 1
        progress?.localizedDescription = "Scanning video text"
        if let video {
            do {
                let text = try await withLocalFile(video, fallbackExtension: "mp4") { url in
                    try await ReelOCR.annotate(videoURL: url, speech: speech)
                }
                progress?.completedUnitCount = 2
                return text
            } catch {
                try Task.checkCancellation()
                logger.error("Reel OCR failed; returning speech-only text: \(error.localizedDescription, privacy: .private)")
            }
        }
        progress?.completedUnitCount = 2
        return speech.map(\.text).joined(separator: " ")
    }
}

@available(iOS 27.0, *)
extension TranscribeReelIntent: LongRunningIntent, CancellableIntent {}

private func withLocalFile<T>(
    _ file: IntentFile,
    fallbackExtension: String,
    operation: (URL) async throws -> T
) async throws -> T {
    if let url = file.fileURL {
        guard url.isFileURL else { throw LocalMediaError.unreadableFile }
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        return try await operation(url)
    }

    let data = file.data
    guard !data.isEmpty else { throw LocalMediaError.unreadableFile }
    let manager = FileManager.default
    let directory = manager.temporaryDirectory.appendingPathComponent("mediadl-\(UUID().uuidString)")
    try manager.createDirectory(at: directory, withIntermediateDirectories: false)
    defer { try? manager.removeItem(at: directory) }
    let fileExtension = URL(fileURLWithPath: file.filename).pathExtension
    let url = directory.appendingPathComponent("input")
        .appendingPathExtension(fileExtension.isEmpty ? fallbackExtension : fileExtension)
    try data.write(to: url, options: .atomic)
    return try await operation(url)
}

private enum LocalMediaError: LocalizedError {
    case unreadableFile

    var errorDescription: String? {
        "The supplied media is not a readable local file."
    }
}

struct MediaDLSpeechShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: TranscribeAudioIntent(),
            phrases: ["Transcribe audio with \(.applicationName)"],
            shortTitle: "Transcribe Audio",
            systemImageName: "waveform"
        )
        AppShortcut(
            intent: TranscribeReelIntent(),
            phrases: ["Transcribe a Reel with \(.applicationName)"],
            shortTitle: "Transcribe Reel",
            systemImageName: "captions.bubble"
        )
    }
}
