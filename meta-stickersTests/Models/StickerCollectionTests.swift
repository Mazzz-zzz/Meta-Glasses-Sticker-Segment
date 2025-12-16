//
//  StickerCollectionTests.swift
//  meta-stickersTests
//

import Foundation
import Testing
import SwiftData
@testable import meta_stickers

@Suite("StickerCollection Model Tests")
struct StickerCollectionTests {

    // MARK: - Initialization Tests

    @Test("Initialization sets name and defaults correctly")
    func init_setsNameAndDefaults() {
        let collection = StickerCollection(name: "My Collection")

        #expect(collection.name == "My Collection")
        #expect(collection.stickers.isEmpty)
        #expect(collection.id != UUID()) // Has a valid UUID
    }

    @Test("Initialization generates unique ID")
    func init_generatesUniqueId() {
        let collection1 = StickerCollection(name: "Collection 1")
        let collection2 = StickerCollection(name: "Collection 2")

        #expect(collection1.id != collection2.id)
    }

    @Test("Initialization sets creation date")
    func init_setsCreationDate() {
        let beforeCreation = Date()
        let collection = StickerCollection(name: "Test")
        let afterCreation = Date()

        #expect(collection.createdAt >= beforeCreation)
        #expect(collection.createdAt <= afterCreation)
    }

    // MARK: - Stickers Array Tests

    @Test("Stickers array defaults to empty")
    func stickers_defaultsEmpty() {
        let collection = StickerCollection(name: "Test")

        #expect(collection.stickers.isEmpty)
        #expect(collection.stickerCount == 0)
    }

    @Test("Stickers can be added to collection")
    func stickers_canBeAdded() {
        let collection = StickerCollection(name: "Test")
        let sticker = TestFixtures.createTestSticker()

        collection.stickers.append(sticker)

        #expect(collection.stickers.count == 1)
        #expect(collection.stickerCount == 1)
    }

    @Test("Multiple stickers can be added")
    func stickers_multipleCanBeAdded() {
        let collection = StickerCollection(name: "Test")
        let sticker1 = TestFixtures.createTestSticker(prompt: "sticker1")
        let sticker2 = TestFixtures.createTestSticker(prompt: "sticker2")
        let sticker3 = TestFixtures.createTestSticker(prompt: "sticker3")

        collection.stickers.append(contentsOf: [sticker1, sticker2, sticker3])

        #expect(collection.stickerCount == 3)
    }

    // MARK: - Convenience Properties Tests

    @Test("stickerCount returns correct count")
    func stickerCount_returnsCorrectCount() {
        let collection = StickerCollection(name: "Test")

        #expect(collection.stickerCount == 0)

        collection.stickers.append(TestFixtures.createTestSticker())
        #expect(collection.stickerCount == 1)

        collection.stickers.append(TestFixtures.createTestSticker())
        #expect(collection.stickerCount == 2)
    }

    @Test("previewStickers returns first 4 stickers")
    func previewStickers_returnsFirstFour() {
        let collection = StickerCollection(name: "Test")

        // Add 6 stickers
        for i in 0..<6 {
            collection.stickers.append(TestFixtures.createTestSticker(prompt: "sticker\(i)"))
        }

        let preview = collection.previewStickers

        #expect(preview.count == 4)
        #expect(preview[0].prompt == "sticker0")
        #expect(preview[3].prompt == "sticker3")
    }

    @Test("previewStickers returns all stickers when less than 4")
    func previewStickers_returnsAllWhenLessThanFour() {
        let collection = StickerCollection(name: "Test")

        collection.stickers.append(TestFixtures.createTestSticker(prompt: "sticker1"))
        collection.stickers.append(TestFixtures.createTestSticker(prompt: "sticker2"))

        let preview = collection.previewStickers

        #expect(preview.count == 2)
    }

    @Test("previewStickers returns empty when no stickers")
    func previewStickers_returnsEmptyWhenNone() {
        let collection = StickerCollection(name: "Test")

        #expect(collection.previewStickers.isEmpty)
    }

    // MARK: - Name Tests

    @Test("Name can be modified")
    func name_canBeModified() {
        let collection = StickerCollection(name: "Original")

        collection.name = "Modified"

        #expect(collection.name == "Modified")
    }

    @Test("Name can be empty string")
    func name_canBeEmpty() {
        let collection = StickerCollection(name: "")

        #expect(collection.name == "")
    }
}
