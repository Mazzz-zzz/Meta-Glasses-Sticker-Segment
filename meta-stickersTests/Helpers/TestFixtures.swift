//
//  TestFixtures.swift
//  meta-stickersTests
//

import Foundation
import UIKit
@testable import meta_stickers

/// Factory methods for creating test data
enum TestFixtures {

    // MARK: - Image Data

    /// Creates test image data with specified size and color
    static func createTestImageData(
        size: CGSize = CGSize(width: 100, height: 100),
        color: UIColor = .red
    ) -> Data {
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
        return image.pngData()!
    }

    /// Creates a test UIImage
    static func createTestImage(
        size: CGSize = CGSize(width: 100, height: 100),
        color: UIColor = .red
    ) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }

    /// Creates test image data with transparency (for cropping tests)
    static func createTransparentTestImageData(
        size: CGSize = CGSize(width: 100, height: 100),
        contentRect: CGRect = CGRect(x: 25, y: 25, width: 50, height: 50)
    ) -> Data {
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            // Fill with transparent background
            UIColor.clear.setFill()
            context.fill(CGRect(origin: .zero, size: size))

            // Draw opaque content in the specified rect
            UIColor.blue.setFill()
            context.fill(contentRect)
        }
        return image.pngData()!
    }

    /// Creates a fully transparent test image
    static func createFullyTransparentImageData(size: CGSize = CGSize(width: 100, height: 100)) -> Data {
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            UIColor.clear.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
        return image.pngData()!
    }

    // MARK: - Model Fixtures

    /// Creates a test Sticker with customizable properties
    static func createTestSticker(
        imageData: Data? = nil,
        prompt: String = "test prompt",
        score: Float? = nil,
        boundingBox: [Float]? = nil,
        isFavorite: Bool = false,
        tags: [String] = []
    ) -> Sticker {
        let data = imageData ?? createTestImageData()
        let sticker = Sticker(
            imageData: data,
            prompt: prompt,
            score: score,
            boundingBox: boundingBox
        )
        sticker.isFavorite = isFavorite
        sticker.tags = tags
        return sticker
    }

    /// Creates a test StickerCollection
    static func createTestCollection(name: String = "Test Collection") -> StickerCollection {
        StickerCollection(name: name)
    }

    /// Creates test AppSettings with default values
    static func createTestSettings() -> AppSettings {
        AppSettings()
    }

    // MARK: - Segmentation Result Fixtures

    /// Creates a test SegmentationResult
    static func createTestSegmentationResult(
        maskImage: UIImage? = nil,
        maskURL: String? = "https://example.com/mask.png",
        score: Float? = 0.95,
        boundingBox: [Float]? = [10, 10, 90, 90]
    ) -> SegmentationResult {
        SegmentationResult(
            maskImage: maskImage ?? createTestImage(),
            maskURL: maskURL,
            score: score,
            boundingBox: boundingBox,
            timestamp: Date()
        )
    }

    // MARK: - JSON Fixtures

    /// Sample SAM3 API success response JSON
    static let sam3SuccessResponseJSON = """
    {
        "image": {
            "url": "https://fal.media/files/test/mask.png",
            "content_type": "image/png",
            "width": 512,
            "height": 512
        },
        "masks": [
            {
                "url": "https://fal.media/files/test/mask.png",
                "content_type": "image/png"
            }
        ],
        "scores": [0.95],
        "boxes": [[10.0, 10.0, 90.0, 90.0]]
    }
    """.data(using: .utf8)!

    /// Sample queue submit response JSON
    static let queueSubmitResponseJSON = """
    {
        "request_id": "test-request-id-123",
        "response_url": "https://queue.fal.run/fal-ai/sam-3/requests/test-request-id-123",
        "status_url": "https://queue.fal.run/fal-ai/sam-3/requests/test-request-id-123/status"
    }
    """.data(using: .utf8)!

    /// Sample queue status response JSON (completed)
    static let queueCompletedStatusJSON = """
    {
        "status": "COMPLETED",
        "response_url": "https://queue.fal.run/fal-ai/sam-3/requests/test-request-id-123"
    }
    """.data(using: .utf8)!

    /// Sample queue status response JSON (pending)
    static let queuePendingStatusJSON = """
    {
        "status": "IN_QUEUE"
    }
    """.data(using: .utf8)!
}
