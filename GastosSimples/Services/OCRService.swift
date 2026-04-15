import Vision
import UIKit

/// A single recognized text line with its normalized position in the image.
/// Vision coordinate system: origin = bottom-left, y=1 = top of image.
struct OCRLine: Sendable {
    let text: String
    /// Normalized bounding box in Vision coordinates (y=0 bottom, y=1 top).
    let box: CGRect

    /// True when the line sits in the top-right corner of the image —
    /// the typical position of a notification timestamp on iOS screenshots.
    var isNotificationTimestamp: Bool {
        box.minX > 0.55 && box.minY > 0.72
    }
}

/// Performs on-device OCR using Apple's Vision framework.
/// Declared as an `actor` so Vision work runs off the main thread safely.
actor OCRService {
    static let shared = OCRService()
    private init() {}

    func recognizeText(in image: UIImage) async throws -> [OCRLine] {
        guard let cgImage = image.cgImage else {
            throw OCRError.invalidImage
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                // Sort top-to-bottom (Vision y=0 is bottom of image, so high y = top)
                let lines = observations
                    .sorted { $0.boundingBox.origin.y > $1.boundingBox.origin.y }
                    .compactMap { obs -> OCRLine? in
                        guard let text = obs.topCandidates(1).first?.string else { return nil }
                        return OCRLine(text: text, box: obs.boundingBox)
                    }
                continuation.resume(returning: lines)
            }

            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["pt-BR", "en-US"]
            request.usesLanguageCorrection = true
            request.revision = VNRecognizeTextRequestRevision3

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    enum OCRError: LocalizedError {
        case invalidImage

        var errorDescription: String? {
            switch self {
            case .invalidImage: "The selected image could not be processed."
            }
        }
    }
}
