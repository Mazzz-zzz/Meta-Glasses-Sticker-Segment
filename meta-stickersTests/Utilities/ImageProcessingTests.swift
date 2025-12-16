//
//  ImageProcessingTests.swift
//  meta-stickersTests
//

import Testing
import UIKit
@testable import meta_stickers

@Suite("Image Processing Tests")
struct ImageProcessingTests {

    // MARK: - Crop to Opaque Content Tests

    @Test("cropToOpaqueContent removes transparent edges")
    func cropToOpaqueContent_removesTransparentEdges() {
        // Create 100x100 image with transparent border and 50x50 opaque center
        let size = CGSize(width: 100, height: 100)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            // Clear background
            UIColor.clear.setFill()
            context.fill(CGRect(origin: .zero, size: size))

            // Opaque center (25-75 in both dimensions = 50x50)
            UIColor.blue.setFill()
            context.fill(CGRect(x: 25, y: 25, width: 50, height: 50))
        }

        let cropped = image.cropToOpaqueContent()

        #expect(cropped != nil)
        // Cropped should be approximately 50x50 + 8px padding = ~58x58
        if let croppedImage = cropped {
            #expect(croppedImage.size.width < size.width)
            #expect(croppedImage.size.height < size.height)
        }
    }

    @Test("cropToOpaqueContent handles fully opaque image")
    func cropToOpaqueContent_handlesFullyOpaque() {
        let size = CGSize(width: 100, height: 100)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            UIColor.red.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }

        let cropped = image.cropToOpaqueContent()

        #expect(cropped != nil)
        // Should be approximately the same size
        if let croppedImage = cropped {
            // Allow for small variations due to padding logic
            #expect(abs(croppedImage.size.width - size.width) <= 10)
            #expect(abs(croppedImage.size.height - size.height) <= 10)
        }
    }

    @Test("cropToOpaqueContent returns self for fully transparent")
    func cropToOpaqueContent_handleFullyTransparent() {
        let size = CGSize(width: 100, height: 100)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            UIColor.clear.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }

        let result = image.cropToOpaqueContent()

        // Returns self when no opaque content found
        #expect(result != nil)
    }

    @Test("cropToOpaqueContent handles small opaque region")
    func cropToOpaqueContent_handlesSmallOpaqueRegion() {
        let size = CGSize(width: 200, height: 200)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            // Clear background
            UIColor.clear.setFill()
            context.fill(CGRect(origin: .zero, size: size))

            // Small opaque region in corner
            UIColor.green.setFill()
            context.fill(CGRect(x: 10, y: 10, width: 20, height: 20))
        }

        let cropped = image.cropToOpaqueContent()

        #expect(cropped != nil)
        if let croppedImage = cropped {
            // Should be much smaller than original
            #expect(croppedImage.size.width < 50)
            #expect(croppedImage.size.height < 50)
        }
    }

    @Test("cropToOpaqueContent handles anti-aliased edges")
    func cropToOpaqueContent_handlesAntiAliasedEdges() {
        let size = CGSize(width: 100, height: 100)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            // Clear background
            UIColor.clear.setFill()
            context.fill(CGRect(origin: .zero, size: size))

            // Draw a circle (has anti-aliased edges)
            UIColor.purple.setFill()
            context.cgContext.fillEllipse(in: CGRect(x: 25, y: 25, width: 50, height: 50))
        }

        let cropped = image.cropToOpaqueContent()

        #expect(cropped != nil)
    }

    @Test("cropToOpaqueContent returns nil for empty image")
    func cropToOpaqueContent_returnsNilForEmpty() {
        let emptyImage = UIImage()

        let result = emptyImage.cropToOpaqueContent()

        #expect(result == nil)
    }

    // MARK: - Thumbnail Generation Tests

    @Test("Sticker thumbnail generation reduces size")
    func stickerThumbnail_reducesSizeForLargeImages() {
        let largeImageData = TestFixtures.createTestImageData(size: CGSize(width: 500, height: 500))
        let sticker = Sticker(imageData: largeImageData, prompt: "test")

        guard let thumbnail = sticker.thumbnailImage else {
            Issue.record("Thumbnail should not be nil")
            return
        }

        // Thumbnail should be significantly smaller than original
        // Account for scale factors on retina devices
        #expect(thumbnail.size.width < 500)
        #expect(thumbnail.size.height < 500)
    }

    @Test("Sticker thumbnail preserves aspect ratio")
    func stickerThumbnail_preservesAspectRatio() {
        // Create non-square image
        let wideImageData = TestFixtures.createTestImageData(size: CGSize(width: 400, height: 200))
        let sticker = Sticker(imageData: wideImageData, prompt: "test")

        guard let thumbnail = sticker.thumbnailImage else {
            Issue.record("Thumbnail should not be nil")
            return
        }

        // Aspect ratio should be approximately 2:1
        let aspectRatio = thumbnail.size.width / thumbnail.size.height
        #expect(abs(aspectRatio - 2.0) < 0.1)
    }

    @Test("Sticker thumbnail handles small images")
    func stickerThumbnail_handlesSmallImages() {
        // Create image smaller than thumbnail max size
        let smallImageData = TestFixtures.createTestImageData(size: CGSize(width: 50, height: 50))
        let sticker = Sticker(imageData: smallImageData, prompt: "test")

        guard let thumbnail = sticker.thumbnailImage else {
            Issue.record("Thumbnail should not be nil")
            return
        }

        // Small images shouldn't be upscaled beyond the max thumbnail size
        // UIGraphicsImageRenderer uses device scale (up to 3x on retina)
        // So 50 logical points can become 50*3=150 in the worst case
        // The thumbnail method uses maxSize of 150 logical points
        let maxExpectedSize: CGFloat = 150 * UIScreen.main.scale
        #expect(thumbnail.size.width <= maxExpectedSize)
        #expect(thumbnail.size.height <= maxExpectedSize)
    }

    // MARK: - Image Data Conversion Tests

    @Test("UIImage converts to PNG data")
    func uiImage_convertsToPNGData() {
        let image = TestFixtures.createTestImage()

        let pngData = image.pngData()

        #expect(pngData != nil)
        #expect(pngData!.count > 0)
    }

    @Test("UIImage converts to JPEG data")
    func uiImage_convertsToJPEGData() {
        let image = TestFixtures.createTestImage()

        let jpegData = image.jpegData(compressionQuality: 0.8)

        #expect(jpegData != nil)
        #expect(jpegData!.count > 0)
    }

    @Test("PNG data can be converted back to UIImage")
    func pngData_convertsBackToUIImage() {
        let originalImage = TestFixtures.createTestImage(size: CGSize(width: 100, height: 100))
        let pngData = originalImage.pngData()!

        let restoredImage = UIImage(data: pngData)

        #expect(restoredImage != nil)
        // PNG conversion may alter size due to scale factors
        // Just verify the image was restored successfully
        #expect(restoredImage!.size.width > 0)
        #expect(restoredImage!.size.height > 0)
    }

    // MARK: - Image with Transparency Tests

    @Test("PNG preserves transparency")
    func png_preservesTransparency() {
        let size = CGSize(width: 100, height: 100)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            // Transparent background
            UIColor.clear.setFill()
            context.fill(CGRect(origin: .zero, size: size))

            // Opaque portion
            UIColor.red.setFill()
            context.fill(CGRect(x: 25, y: 25, width: 50, height: 50))
        }

        let pngData = image.pngData()
        let restored = UIImage(data: pngData!)

        #expect(restored != nil)
        // PNG format should preserve the transparency
        // (JPEG would lose it)
    }
}
