//
//  OCRService.swift
//  ClipCV
//

import AppKit
import Vision

enum OCRService {
    static func recognizeText(in imageData: Data) async -> String? {
        guard let cgImage = NSImage(data: imageData)?
            .cgImage(forProposedRect: nil, context: nil, hints: nil)
        else { return nil }

        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, _ in
                let text = ((request.results as? [VNRecognizedTextObservation]) ?? [])
                    .compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: "\n")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                continuation.resume(returning: text.isEmpty ? nil : text)
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["zh-Hans", "zh-Hant", "en-US"]

            if (try? VNImageRequestHandler(cgImage: cgImage).perform([request])) == nil {
                continuation.resume(returning: nil)
            }
        }
    }
}
