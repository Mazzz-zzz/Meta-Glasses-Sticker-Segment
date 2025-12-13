import Foundation
import CoreGraphics
import UIKit

// MARK: - Detection Result

/// A detected object from YOLO-World
struct DetectedObject: Sendable {
    /// Bounding box in normalized coordinates (0-1)
    let boundingBox: CGRect
    /// Detection confidence (0-1)
    let confidence: Float
    /// The prompt/class that was detected
    let label: String
}

// MARK: - Segmentation Result

/// A segmented object with mask
struct SegmentationResult: Sendable {
    /// The binary mask as a CGImage (grayscale, white = object)
    let mask: CGImage
    /// Bounding box in normalized coordinates (0-1)
    let boundingBox: CGRect
    /// Detection confidence (0-1)
    let confidence: Float
    /// The prompt used for detection
    let prompt: String
    /// Original frame size
    let frameSize: CGSize
}

// MARK: - Inference Quality

enum InferenceQuality: String, CaseIterable, Sendable {
    case fast = "Fast"
    case balanced = "Balanced"
    case best = "Best"

    var yoloInputSize: Int {
        switch self {
        case .fast: return 480
        case .balanced: return 640
        case .best: return 640
        }
    }

    var useSAM: Bool {
        switch self {
        case .fast: return false  // Boxes only, no masks
        case .balanced, .best: return true
        }
    }

    var targetFPS: Double {
        switch self {
        case .fast: return 15.0
        case .balanced: return 10.0
        case .best: return 5.0
        }
    }

    var description: String {
        switch self {
        case .fast: return "Fast (boxes only)"
        case .balanced: return "Balanced (with masks)"
        case .best: return "Best quality"
        }
    }
}

// MARK: - Errors

enum SegmentationError: Error, LocalizedError {
    case modelNotLoaded
    case modelNotFound(String)
    case preprocessingFailed
    case inferenceFailed(String)
    case postprocessingFailed
    case noDetections
    case maskGenerationFailed

    var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            return "Model not loaded"
        case .modelNotFound(let name):
            return "Model not found: \(name)"
        case .preprocessingFailed:
            return "Failed to preprocess image"
        case .inferenceFailed(let reason):
            return "Inference failed: \(reason)"
        case .postprocessingFailed:
            return "Failed to postprocess results"
        case .noDetections:
            return "No objects detected"
        case .maskGenerationFailed:
            return "Failed to generate mask"
        }
    }
}

// MARK: - Segmentation Service Protocol

/// Protocol for segmentation services (allows mock and real implementations)
protocol SegmentationServiceProtocol: Actor {
    /// Load models and prepare for inference
    func load() async throws

    /// Check if service is ready
    var isLoaded: Bool { get async }

    /// Segment objects matching the prompt in the image
    func segment(image: CGImage, prompt: String, quality: InferenceQuality) async throws -> [SegmentationResult]

    /// Detect objects only (no masks) - faster
    func detect(image: CGImage, prompt: String) async throws -> [DetectedObject]
}

// MARK: - Cutout Utilities

extension SegmentationResult {
    /// Apply the mask to extract a cutout from the original image
    func extractCutout(from originalImage: CGImage, padding: CGFloat = 0.05) -> UIImage? {
        let imageWidth = CGFloat(originalImage.width)
        let imageHeight = CGFloat(originalImage.height)

        // Convert normalized bbox to pixel coordinates with padding
        let paddedBox = CGRect(
            x: max(0, boundingBox.minX - padding) * imageWidth,
            y: max(0, boundingBox.minY - padding) * imageHeight,
            width: min(1, boundingBox.width + 2 * padding) * imageWidth,
            height: min(1, boundingBox.height + 2 * padding) * imageHeight
        )

        // Clamp to image bounds
        let clampedBox = paddedBox.intersection(CGRect(x: 0, y: 0, width: imageWidth, height: imageHeight))

        guard !clampedBox.isEmpty else { return nil }

        // Create context for the cutout
        let size = clampedBox.size
        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
        defer { UIGraphicsEndImageContext() }

        guard let context = UIGraphicsGetCurrentContext() else { return nil }

        // Flip coordinate system
        context.translateBy(x: 0, y: size.height)
        context.scaleBy(x: 1, y: -1)

        // Crop original image to bbox
        guard let croppedImage = originalImage.cropping(to: clampedBox) else { return nil }

        // Scale mask to match cropped area
        let maskRect = CGRect(origin: .zero, size: size)

        // Draw mask as clip
        context.saveGState()

        // Scale and position mask
        let maskScaleX = size.width / CGFloat(mask.width)
        let maskScaleY = size.height / CGFloat(mask.height)

        context.scaleBy(x: maskScaleX, y: maskScaleY)
        context.clip(to: CGRect(x: 0, y: 0, width: CGFloat(mask.width), height: CGFloat(mask.height)), mask: mask)
        context.scaleBy(x: 1/maskScaleX, y: 1/maskScaleY)

        // Draw the cropped image
        context.draw(croppedImage, in: maskRect)

        context.restoreGState()

        return UIGraphicsGetImageFromCurrentImageContext()
    }
}
