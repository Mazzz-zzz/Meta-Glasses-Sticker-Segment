import Foundation
import CoreGraphics
import UIKit

/// Mock segmentation service for testing UI without real models
actor MockSegmentationService: SegmentationServiceProtocol {
    private var _isLoaded = false

    var isLoaded: Bool {
        _isLoaded
    }

    func load() async throws {
        // Simulate model loading delay
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5s
        _isLoaded = true
    }

    func detect(image: CGImage, prompt: String) async throws -> [DetectedObject] {
        guard _isLoaded else { throw SegmentationError.modelNotLoaded }

        // Simulate inference delay
        try await Task.sleep(nanoseconds: 50_000_000) // 50ms

        // Return mock detections based on prompt
        // In real usage, this would run YOLO-World
        return generateMockDetections(for: prompt, imageSize: CGSize(width: image.width, height: image.height))
    }

    func segment(image: CGImage, prompt: String, quality: InferenceQuality) async throws -> [SegmentationResult] {
        guard _isLoaded else { throw SegmentationError.modelNotLoaded }

        // Get detections first
        let detections = try await detect(image: image, prompt: prompt)

        guard !detections.isEmpty else {
            throw SegmentationError.noDetections
        }

        // If fast mode, return box-only results with simple rectangular masks
        if !quality.useSAM {
            return detections.map { detection in
                SegmentationResult(
                    mask: createRectangularMask(for: detection.boundingBox, imageSize: CGSize(width: image.width, height: image.height)),
                    boundingBox: detection.boundingBox,
                    confidence: detection.confidence,
                    prompt: prompt,
                    frameSize: CGSize(width: image.width, height: image.height)
                )
            }
        }

        // Simulate SAM inference delay
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms

        // Generate mock elliptical masks (simulating SAM output)
        return detections.map { detection in
            SegmentationResult(
                mask: createEllipticalMask(for: detection.boundingBox, imageSize: CGSize(width: image.width, height: image.height)),
                boundingBox: detection.boundingBox,
                confidence: detection.confidence,
                prompt: prompt,
                frameSize: CGSize(width: image.width, height: image.height)
            )
        }
    }

    // MARK: - Mock Data Generation

    private func generateMockDetections(for prompt: String, imageSize: CGSize) -> [DetectedObject] {
        // Generate 1-3 random detections
        let count = Int.random(in: 1...3)

        return (0..<count).map { i in
            // Random position, biased toward center
            let centerX = 0.3 + CGFloat.random(in: 0...0.4)
            let centerY = 0.3 + CGFloat.random(in: 0...0.4)
            let width = CGFloat.random(in: 0.15...0.35)
            let height = CGFloat.random(in: 0.15...0.35)

            return DetectedObject(
                boundingBox: CGRect(
                    x: centerX - width/2,
                    y: centerY - height/2,
                    width: width,
                    height: height
                ),
                confidence: Float.random(in: 0.7...0.95),
                label: prompt
            )
        }
    }

    private func createRectangularMask(for bbox: CGRect, imageSize: CGSize) -> CGImage {
        let width = Int(imageSize.width * bbox.width)
        let height = Int(imageSize.height * bbox.height)

        // Create a simple white rectangle on black background
        let size = CGSize(width: max(1, width), height: max(1, height))
        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
        defer { UIGraphicsEndImageContext() }

        let context = UIGraphicsGetCurrentContext()!

        // Fill with white (mask = 1)
        context.setFillColor(UIColor.white.cgColor)
        context.fill(CGRect(origin: .zero, size: size))

        return context.makeImage()!
    }

    private func createEllipticalMask(for bbox: CGRect, imageSize: CGSize) -> CGImage {
        let width = Int(imageSize.width * bbox.width)
        let height = Int(imageSize.height * bbox.height)

        let size = CGSize(width: max(1, width), height: max(1, height))
        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
        defer { UIGraphicsEndImageContext() }

        let context = UIGraphicsGetCurrentContext()!

        // Fill background with black (mask = 0)
        context.setFillColor(UIColor.black.cgColor)
        context.fill(CGRect(origin: .zero, size: size))

        // Draw white ellipse (mask = 1)
        context.setFillColor(UIColor.white.cgColor)

        // Add some randomness to make it look more organic
        let inset = CGFloat.random(in: 0.05...0.1)
        let ellipseRect = CGRect(origin: .zero, size: size).insetBy(
            dx: size.width * inset,
            dy: size.height * inset
        )
        context.fillEllipse(in: ellipseRect)

        return context.makeImage()!
    }
}

// MARK: - Preview Helper

extension MockSegmentationService {
    /// Create a test image for previewing
    static func createTestImage(size: CGSize = CGSize(width: 640, height: 480)) -> CGImage? {
        UIGraphicsBeginImageContextWithOptions(size, true, 1.0)
        defer { UIGraphicsEndImageContext() }

        guard let context = UIGraphicsGetCurrentContext() else { return nil }

        // Gradient background
        let colors = [UIColor.systemBlue.cgColor, UIColor.systemPurple.cgColor]
        let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: nil)!
        context.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: size.width, y: size.height), options: [])

        // Add some shapes to simulate objects
        context.setFillColor(UIColor.systemOrange.cgColor)
        context.fillEllipse(in: CGRect(x: size.width * 0.3, y: size.height * 0.3, width: size.width * 0.25, height: size.height * 0.3))

        context.setFillColor(UIColor.systemGreen.cgColor)
        context.fill(CGRect(x: size.width * 0.6, y: size.height * 0.5, width: size.width * 0.2, height: size.height * 0.25))

        return context.makeImage()
    }
}
