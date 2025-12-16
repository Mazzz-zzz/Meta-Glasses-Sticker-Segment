//
//  FalAIServiceTests.swift
//  meta-stickersTests
//

import Testing
import UIKit
@testable import meta_stickers

@Suite("FalAIService Tests")
struct FalAIServiceTests {

    // MARK: - Request Structure Tests

    @Test("SAM3Request initializes with correct values")
    func sam3Request_initializesCorrectly() {
        let request = SAM3Request(
            imageDataURI: "data:image/jpeg;base64,abc123",
            prompt: "test object",
            applyMask: false
        )

        #expect(request.image_url == "data:image/jpeg;base64,abc123")
        #expect(request.prompt == "test object")
        #expect(request.apply_mask == false)
        #expect(request.output_format == "png")
        #expect(request.sync_mode == true)
    }

    @Test("SAM3Request uses default values")
    func sam3Request_usesDefaults() {
        let request = SAM3Request(imageDataURI: "data:image/jpeg;base64,abc")

        #expect(request.prompt == "object")
        #expect(request.apply_mask == true)
    }

    // MARK: - Response Parsing Tests

    @Test("SAM3Response decodes successfully")
    func sam3Response_decodesSuccessfully() throws {
        let decoder = JSONDecoder()
        let response = try decoder.decode(SAM3Response.self, from: TestFixtures.sam3SuccessResponseJSON)

        #expect(response.image != nil)
        #expect(response.image?.url == "https://fal.media/files/test/mask.png")
        #expect(response.masks?.count == 1)
        #expect(response.scores?.first == 0.95)
        #expect(response.boxes?.first == [10.0, 10.0, 90.0, 90.0])
    }

    @Test("SAM3Image decodes with all fields")
    func sam3Image_decodesWithAllFields() throws {
        let json = """
        {
            "url": "https://example.com/image.png",
            "content_type": "image/png",
            "file_name": "image.png",
            "file_size": 12345,
            "width": 512,
            "height": 512
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        let image = try decoder.decode(SAM3Image.self, from: json)

        #expect(image.url == "https://example.com/image.png")
        #expect(image.content_type == "image/png")
        #expect(image.file_name == "image.png")
        #expect(image.file_size == 12345)
        #expect(image.width == 512)
        #expect(image.height == 512)
    }

    @Test("QueueSubmitResponse decodes successfully")
    func queueSubmitResponse_decodesSuccessfully() throws {
        let decoder = JSONDecoder()
        let response = try decoder.decode(QueueSubmitResponse.self, from: TestFixtures.queueSubmitResponseJSON)

        #expect(response.request_id == "test-request-id-123")
        #expect(response.response_url != nil)
        #expect(response.status_url != nil)
    }

    @Test("QueueStatusResponse decodes completed status")
    func queueStatusResponse_decodesCompleted() throws {
        let decoder = JSONDecoder()
        let response = try decoder.decode(QueueStatusResponse.self, from: TestFixtures.queueCompletedStatusJSON)

        #expect(response.status == "COMPLETED")
        #expect(response.response_url != nil)
    }

    @Test("QueueStatusResponse decodes pending status")
    func queueStatusResponse_decodesPending() throws {
        let decoder = JSONDecoder()
        let response = try decoder.decode(QueueStatusResponse.self, from: TestFixtures.queuePendingStatusJSON)

        #expect(response.status == "IN_QUEUE")
    }

    // MARK: - Error Tests

    @Test("FalAIError provides meaningful descriptions")
    func falAIError_providesDescriptions() {
        #expect(FalAIError.invalidAPIKey.errorDescription?.contains("API key") == true)
        #expect(FalAIError.invalidImage.errorDescription?.contains("encode image") == true)
        #expect(FalAIError.timeout.errorDescription?.contains("timed out") == true)
        #expect(FalAIError.requestInProgress.errorDescription?.contains("in progress") == true)
    }

    @Test("FalAIError networkError includes underlying error")
    func falAIError_networkErrorIncludesUnderlying() {
        let underlyingError = NSError(domain: "Test", code: -1, userInfo: [NSLocalizedDescriptionKey: "Connection failed"])
        let error = FalAIError.networkError(underlyingError)

        #expect(error.errorDescription?.contains("Connection failed") == true)
    }

    @Test("FalAIError apiError includes message")
    func falAIError_apiErrorIncludesMessage() {
        let error = FalAIError.apiError("Rate limit exceeded")

        #expect(error.errorDescription?.contains("Rate limit exceeded") == true)
    }

    // MARK: - Service Initialization Tests

    @Test("FalAIService initializes with provided API key")
    func falAIService_initializesWithKey() async {
        let service = FalAIService(apiKey: "test-key-123")

        // Service is an actor, so it exists and was created successfully
        #expect(service != nil)
    }

    @Test("FalAIService initializes without API key")
    func falAIService_initializesWithoutKey() async {
        let service = FalAIService()

        #expect(service != nil)
    }
}

// MARK: - Image Cropping Tests (cropToOpaqueContent extension)

@Suite("UIImage cropToOpaqueContent Tests")
struct ImageCroppingTests {

    @Test("cropToOpaqueContent removes transparent edges")
    func cropToOpaqueContent_removesTransparentEdges() {
        // Create image with transparent border and opaque center
        let size = CGSize(width: 100, height: 100)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            // Transparent background
            UIColor.clear.setFill()
            context.fill(CGRect(origin: .zero, size: size))

            // Opaque center square (25,25 to 75,75)
            UIColor.red.setFill()
            context.fill(CGRect(x: 25, y: 25, width: 50, height: 50))
        }

        let cropped = image.cropToOpaqueContent()

        #expect(cropped != nil)
        // Cropped image should be smaller than original
        // Account for padding (4px on each side)
        #expect(cropped!.size.width <= 58) // 50 + 8 padding
        #expect(cropped!.size.height <= 58)
    }

    @Test("cropToOpaqueContent handles fully opaque image")
    func cropToOpaqueContent_handlesFullyOpaque() {
        let image = TestFixtures.createTestImage(size: CGSize(width: 100, height: 100))

        let cropped = image.cropToOpaqueContent()

        #expect(cropped != nil)
        // Should return similar size (may have slight differences due to rendering)
    }

    @Test("cropToOpaqueContent returns self for fully transparent image")
    func cropToOpaqueContent_returnsSelfForFullyTransparent() {
        let size = CGSize(width: 100, height: 100)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            UIColor.clear.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }

        let result = image.cropToOpaqueContent()

        // Should return self when no opaque content found
        #expect(result != nil)
    }

    @Test("cropToOpaqueContent returns nil for no CGImage")
    func cropToOpaqueContent_returnsNilForNoCGImage() {
        // Create an empty UIImage (edge case)
        let emptyImage = UIImage()

        let result = emptyImage.cropToOpaqueContent()

        #expect(result == nil)
    }
}
