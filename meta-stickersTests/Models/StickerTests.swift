//
//  StickerTests.swift
//  meta-stickersTests
//

import Foundation
import Testing
import SwiftData
import UIKit
@testable import meta_stickers

@Suite("Sticker Model Tests")
struct StickerTests {

    // MARK: - Initialization Tests

    @Test("Default initialization sets expected values")
    func init_setsDefaultValues() {
        let imageData = TestFixtures.createTestImageData()
        let sticker = Sticker(imageData: imageData, prompt: "test")

        #expect(sticker.isFavorite == false)
        #expect(sticker.tags.isEmpty)
        #expect(sticker.score == nil)
        #expect(sticker.boundingBox == nil)
        #expect(sticker.collection == nil)
        #expect(sticker.prompt == "test")
        #expect(sticker.imageData == imageData)
    }

    @Test("Initialization with all parameters sets values correctly")
    func init_withAllParameters() {
        let imageData = TestFixtures.createTestImageData()
        let score: Float = 0.95
        let boundingBox: [Float] = [10, 10, 90, 90]

        let sticker = Sticker(
            imageData: imageData,
            prompt: "custom prompt",
            score: score,
            boundingBox: boundingBox
        )

        #expect(sticker.prompt == "custom prompt")
        #expect(sticker.score == score)
        #expect(sticker.boundingBox == boundingBox)
        #expect(sticker.imageData == imageData)
    }

    @Test("Sticker generates unique ID")
    func init_generatesUniqueId() {
        let imageData = TestFixtures.createTestImageData()
        let sticker1 = Sticker(imageData: imageData, prompt: "test1")
        let sticker2 = Sticker(imageData: imageData, prompt: "test2")

        #expect(sticker1.id != sticker2.id)
    }

    @Test("Sticker sets creation date on init")
    func init_setsCreationDate() {
        let beforeCreation = Date()
        let sticker = Sticker(imageData: TestFixtures.createTestImageData(), prompt: "test")
        let afterCreation = Date()

        #expect(sticker.createdAt >= beforeCreation)
        #expect(sticker.createdAt <= afterCreation)
    }

    // MARK: - Thumbnail Generation Tests

    @Test("Thumbnail is generated from image data")
    func thumbnailImage_generatesFromImageData() {
        let imageData = TestFixtures.createTestImageData(size: CGSize(width: 200, height: 200))
        let sticker = Sticker(imageData: imageData, prompt: "test")

        #expect(sticker.thumbnailData != nil)
        #expect(sticker.thumbnailImage != nil)
    }

    @Test("Thumbnail is smaller than original for large images")
    func thumbnailImage_isSmallerThanOriginal() {
        let largeImageData = TestFixtures.createTestImageData(size: CGSize(width: 500, height: 500))
        let sticker = Sticker(imageData: largeImageData, prompt: "test")

        guard let thumbnail = sticker.thumbnailImage else {
            Issue.record("Thumbnail should not be nil")
            return
        }

        // Verify thumbnail is actually smaller than original (main purpose of this test)
        #expect(thumbnail.size.width < 500)
        #expect(thumbnail.size.height < 500)
    }

    @Test("Thumbnail returns nil for invalid data")
    func thumbnailImage_returnsNilForInvalidData() {
        let invalidData = Data([0, 1, 2, 3])
        let sticker = Sticker(imageData: invalidData, prompt: "test")

        #expect(sticker.thumbnailImage == nil)
    }

    @Test("Thumbnail is nil when image data is nil")
    func thumbnailImage_returnsNilForNilData() {
        let sticker = Sticker(imageData: nil, prompt: "test")

        #expect(sticker.thumbnailData == nil)
        #expect(sticker.thumbnailImage == nil)
    }

    // MARK: - Full Image Tests

    @Test("Full image returns UIImage from data")
    func fullImage_returnsUIImageFromData() {
        let imageData = TestFixtures.createTestImageData()
        let sticker = Sticker(imageData: imageData, prompt: "test")

        #expect(sticker.fullImage != nil)
    }

    @Test("Full image returns nil for nil data")
    func fullImage_returnsNilForNilData() {
        let sticker = Sticker(imageData: nil, prompt: "test")

        #expect(sticker.fullImage == nil)
    }

    @Test("Full image returns nil for invalid data")
    func fullImage_returnsNilForInvalidData() {
        let invalidData = Data([0, 1, 2, 3])
        let sticker = Sticker(imageData: invalidData, prompt: "test")

        #expect(sticker.fullImage == nil)
    }

    // MARK: - Favorite Tests

    @Test("isFavorite defaults to false")
    func isFavorite_defaultsFalse() {
        let sticker = TestFixtures.createTestSticker()

        #expect(sticker.isFavorite == false)
    }

    @Test("isFavorite can be toggled")
    func isFavorite_canBeToggled() {
        let sticker = TestFixtures.createTestSticker()

        sticker.isFavorite = true
        #expect(sticker.isFavorite == true)

        sticker.isFavorite = false
        #expect(sticker.isFavorite == false)
    }

    // MARK: - Tags Tests

    @Test("Tags defaults to empty array")
    func tags_defaultsEmpty() {
        let sticker = TestFixtures.createTestSticker()

        #expect(sticker.tags.isEmpty)
    }

    @Test("Tags can be modified")
    func tags_canBeModified() {
        let sticker = TestFixtures.createTestSticker()

        sticker.tags = ["tag1", "tag2"]
        #expect(sticker.tags.count == 2)
        #expect(sticker.tags.contains("tag1"))
        #expect(sticker.tags.contains("tag2"))
    }

    @Test("Tags can be appended")
    func tags_canBeAppended() {
        let sticker = TestFixtures.createTestSticker()

        sticker.tags.append("newTag")
        #expect(sticker.tags.count == 1)
        #expect(sticker.tags.first == "newTag")
    }
}
