import AVFoundation
import Foundation
import Vision

enum ReelOCR {
    private static let maximumSamples = 60
    private static let preferredSampleInterval = 1.5

    private enum ScanError: Error { case noFrames }

    private struct Note {
        let time: Double
        let text: String
        let key: String
        let isAuthorTag: Bool
    }

    static func annotate(videoURL: URL, speech: [SpeechSpan]) async throws -> String {
        let worker = Task.detached(priority: .utility) {
            try await transcribe(videoURL: videoURL, speech: speech)
        }
        return try await withTaskCancellationHandler {
            try await worker.value
        } onCancel: {
            worker.cancel()
        }
    }

    private static func transcribe(videoURL: URL, speech: [SpeechSpan]) async throws -> String {
        let asset = AVURLAsset(url: videoURL)
        let duration = CMTimeGetSeconds(try await asset.load(.duration))
        guard duration.isFinite, duration > 0 else {
            throw ScanError.noFrames
        }

        let cappedDuration = min(duration, Double(maximumSamples) * preferredSampleInterval)
        let sampleCount = max(1, Int(ceil(cappedDuration / preferredSampleInterval)))
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 1280, height: 1280)
        let tolerance = CMTime(seconds: min(0.25, duration / Double(sampleCount) / 4), preferredTimescale: 600)
        generator.requestedTimeToleranceBefore = tolerance
        generator.requestedTimeToleranceAfter = tolerance
        let languages = try supportedLanguages()
        var recognizedFrames = 0
        var notes: [Note] = []
        var lastSeen: [String: Double] = [:]
        var authorTags = Set<String>()
        var sampleCounts: [String: Set<Int>] = [:]

        for index in 0..<sampleCount {
            try Task.checkCancellation()
            let requestedTime = CMTime(
                seconds: duration * (Double(index) + 0.5) / Double(sampleCount),
                preferredTimescale: 600
            )
            guard let frame = try? await generator.image(at: requestedTime) else { continue }
            let time = CMTimeGetSeconds(frame.actualTime)
            guard time.isFinite, time >= 0 else { continue }

            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = false
            request.recognitionLanguages = languages
            try VNImageRequestHandler(cgImage: frame.image).perform([request])
            recognizedFrames += 1

            for observation in request.results ?? [] {
                guard let text = observation.topCandidates(1).first?.string
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                      text.count >= 2 else { continue }
                let handle = authorHandle(in: text)
                let key = normalized(handle ?? text)
                guard !key.isEmpty else { continue }
                let isAuthorTag = handle != nil
                if isAuthorTag, !authorTags.insert(key).inserted { continue }
                sampleCounts[key, default: []].insert(index)
                let previous = lastSeen.updateValue(time, forKey: key)
                if let previous, time - previous < 1.5 * duration / Double(sampleCount) { continue }
                notes.append(Note(time: time, text: handle ?? text, key: key, isAuthorTag: isAuthorTag))
            }
        }

        try Task.checkCancellation()
        let persistenceThreshold = min(sampleCount, max(2, Int(ceil(Double(recognizedFrames) * 0.6))))
        guard recognizedFrames > 0 else { throw ScanError.noFrames }
        let persistentKeys = Set(sampleCounts.compactMap { key, samples in
            samples.count >= persistenceThreshold ? key : nil
        })
        let persistentNotes = Dictionary(grouping: notes.filter { $0.isAuthorTag || persistentKeys.contains($0.key) }, by: \.key)
            .values.compactMap { $0.min { $0.time < $1.time } }
        let timelineNotes = notes.filter { note in
            !note.isAuthorTag && !persistentKeys.contains(note.key)
                && !shouldSuppress(note.text, at: note.time, speech: speech)
        }
        return format(speech: speech, timelineNotes: timelineNotes, persistentNotes: persistentNotes)
    }

    private static func supportedLanguages() throws -> [String] {
        let request = VNRecognizeTextRequest()
        let supported = try request.supportedRecognitionLanguages()
        let preferred = Locale.preferredLanguages
        let matching = preferred.compactMap { language in
            supported.first { $0 == language }
                ?? supported.first { $0.hasPrefix(Locale(identifier: language).language.languageCode?.identifier ?? "") }
        }
        let result = Array(NSOrderedSet(array: matching + supported.filter { ["hi-IN", "en-US"].contains($0) })) as? [String] ?? []
        return result.isEmpty ? Array(supported.prefix(1)) : result
    }

    private static func authorHandle(in text: String) -> String? {
        text.range(of: #"^@[A-Za-z0-9._]{2,30}$"#, options: .regularExpression).map { String(text[$0]) }
    }

    private static func shouldSuppress(_ text: String, at time: Double, speech: [SpeechSpan]) -> Bool {
        let key = normalized(text)
        let words = key.split(separator: " ")
        guard key.count >= 12 || words.count >= 3 else { return false }
        let phrase = key.split(separator: " ").map(String.init)
        return speech.contains { span in
            abs(span.start - time) <= 5
                && containsPhrase(phrase, in: normalized(span.text).split(separator: " ").map(String.init))
        }
    }

    private static func containsPhrase(_ phrase: [String], in words: [String]) -> Bool {
        guard !phrase.isEmpty, phrase.count <= words.count else { return false }
        return (0...(words.count - phrase.count)).contains { start in
            Array(words[start..<(start + phrase.count)]) == phrase
        }
    }

    private static func normalized(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .joined(separator: " ")
    }

    private static func format(speech: [SpeechSpan], timelineNotes: [Note], persistentNotes: [Note]) -> String {
        let timeline = speech.map { (time: $0.start, line: "[\(timestamp($0.start))] \($0.text)") }
            + timelineNotes.map { (time: $0.time, line: "[\(timestamp($0.time))] [ON-SCREEN] \($0.text)") }
        let timelineLines = timeline.sorted { safeTime($0.time) < safeTime($1.time) }.map(\.line)
        let persistentLines = persistentNotes.sorted { $0.time < $1.time }.map {
            "[\(timestamp($0.time))] \($0.text)"
        }
        let timelineSection = "TIMELINE\n\(timelineLines.joined(separator: "\n"))"
        guard !persistentLines.isEmpty else { return timelineSection }
        return "\(timelineSection)\n\nPERSISTENT ON-SCREEN NOTES\n\(persistentLines.joined(separator: "\n"))"
    }

    private static func timestamp(_ seconds: Double) -> String {
        let bounded = min(max(0, safeTime(seconds)), Double(Int.max / 60))
        let wholeSeconds = Int(bounded.rounded(.down))
        return String(format: "%02lld:%02lld", Int64(wholeSeconds / 60), Int64(wholeSeconds % 60))
    }

    private static func safeTime(_ seconds: Double) -> Double {
        seconds.isFinite ? max(0, seconds) : 0
    }
}
