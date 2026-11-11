import Foundation
import Vision

enum OCRService {
    // Vision 的同步识别必须离开主线程，避免大图阻塞界面。
    @concurrent
    static func recognizeText(in imageData: Data) async -> String? {
        guard !Task.isCancelled else { return nil }
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["zh-Hans", "zh-Hant", "en-US"]

        do {
            try VNImageRequestHandler(data: imageData).perform([request])
        } catch {
            return nil
        }
        guard !Task.isCancelled else { return nil }
        let text = (request.results ?? [])
            .compactMap { $0.topCandidates(1).first?.string }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }
}
