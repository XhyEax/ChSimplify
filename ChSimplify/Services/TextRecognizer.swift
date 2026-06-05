//
//  TextRecognizer.swift
//  ChSimplify
//
//  使用 Vision 框架对图片做中文（含繁体）OCR，返回每行文字及其在图中的位置。
//

import Foundation
import UIKit
import Vision

/// 一行识别结果：文字 + 在原图中的边界框（Vision 归一化坐标，原点在左下角）。
struct RecognizedLine: Identifiable {
    let id = UUID()
    let text: String
    let boundingBox: CGRect
}

enum TextRecognizerError: LocalizedError {
    case invalidImage
    case noTextFound

    var errorDescription: String? {
        switch self {
        case .invalidImage: return "无法处理该图片"
        case .noTextFound: return "未在图片中识别到文字"
        }
    }
}

enum TextRecognizer {
    /// 识别图片中的文字，按行返回（含每行边界框）。识别不到文字时抛出 `.noTextFound`。
    static func recognize(_ image: UIImage) async throws -> [RecognizedLine] {
        guard let cgImage = image.cgImage else {
            throw TextRecognizerError.invalidImage
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                let lines: [RecognizedLine] = observations.compactMap { obs in
                    guard let text = obs.topCandidates(1).first?.string,
                          !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                        return nil
                    }
                    return RecognizedLine(text: text, boundingBox: obs.boundingBox)
                }
                if lines.isEmpty {
                    continuation.resume(throwing: TextRecognizerError.noTextFound)
                } else {
                    continuation.resume(returning: lines)
                }
            }
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["zh-Hant", "zh-Hans", "en-US"]
            request.usesLanguageCorrection = true

            // 传入图片方向，使返回的边界框与屏幕上按 orientation 显示的图片对齐。
            let orientation = CGImagePropertyOrientation(image.imageOrientation)
            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try handler.perform([request])
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

private extension CGImagePropertyOrientation {
    init(_ uiOrientation: UIImage.Orientation) {
        switch uiOrientation {
        case .up: self = .up
        case .down: self = .down
        case .left: self = .left
        case .right: self = .right
        case .upMirrored: self = .upMirrored
        case .downMirrored: self = .downMirrored
        case .leftMirrored: self = .leftMirrored
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}
