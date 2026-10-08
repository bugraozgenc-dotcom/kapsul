import Foundation
import Vision
import ImageIO

// Vision runs locally; one serial worker avoids multiple image models consuming
// memory at once when a burst of screenshots arrives.
enum TextRecognition {
    private static let queue = DispatchQueue(label: "Kapsul.TextRecognition", qos: .userInitiated)

    static func recognize(_ url: URL) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do {
                    let request = VNRecognizeTextRequest()
                    // The accurate model can stall in ANE initialization on some macOS builds.
                    // Fast recognition stays responsive for clipboard screenshots.
                    request.recognitionLevel = .fast
                    request.usesLanguageCorrection = true
                    request.automaticallyDetectsLanguage = false
                    let supported = try request.supportedRecognitionLanguages()
                    request.recognitionLanguages = ["tr-TR", "en-US", "fr-FR", "de-DE", "es-ES"].filter { supported.contains($0) }
                    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                          let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                            kCGImageSourceCreateThumbnailFromImageAlways: true,
                            kCGImageSourceCreateThumbnailWithTransform: true,
                            kCGImageSourceThumbnailMaxPixelSize: 2560
                          ] as CFDictionary) else {
                        throw CocoaError(.fileReadCorruptFile)
                    }
                    try VNImageRequestHandler(cgImage: image).perform([request])
                    let observations: [VNRecognizedTextObservation] = request.results ?? []
                    let text = observations.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
                    continuation.resume(returning: text)
                } catch { continuation.resume(throwing: error) }
            }
        }
    }
}
