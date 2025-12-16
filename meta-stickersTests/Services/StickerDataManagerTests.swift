//
//  StickerDataManagerTests.swift
//  meta-stickersTests
//

import Testing
import SwiftData
import UIKit
@testable import meta_stickers

@Suite("StickerDataManager Tests")
@MainActor
struct StickerDataManagerTests {

    // MARK: - Save Sticker Tests

    @Test("saveSticker inserts sticker into context")
    func saveSticker_insertsIntoContext() throws {
        let (dataManager, _) = try TestHelpers.createTestDataManager()
        let testData = TestFixtures.createTestImageData()

        let sticker = dataManager.saveSticker(
            imageData: testData,
            prompt: "test prompt"
        )

        #expect(sticker.prompt == "test prompt")
        #expect(sticker.imageData == testData)

        // Verify in context
        let fetched = dataManager.fetchRecentStickers(limit: 1)
        #expect(fetched.count == 1)
        #expect(fetched.first?.id == sticker.id)
    }

    @Test("saveSticker with score and bounding box")
    func saveSticker_withScoreAndBoundingBox() throws {
        let (dataManager, _) = try TestHelpers.createTestDataManager()
        let testData = TestFixtures.createTestImageData()
        let score: Float = 0.95
        let boundingBox: [Float] = [10, 10, 90, 90]

        let sticker = dataManager.saveSticker(
            imageData: testData,
            prompt: "test",
            score: score,
            boundingBox: boundingBox
        )

        #expect(sticker.score == score)
        #expect(sticker.boundingBox == boundingBox)
    }

    @Test("saveSticker from UIImage converts to data")
    func saveSticker_fromUIImage_convertsData() throws {
        let (dataManager, _) = try TestHelpers.createTestDataManager()
        let testImage = TestFixtures.createTestImage()

        let sticker = dataManager.saveSticker(
            image: testImage,
            prompt: "test prompt"
        )

        #expect(sticker != nil)
        #expect(sticker?.prompt == "test prompt")
        #expect(sticker?.imageData != nil)
    }

    // MARK: - Delete Sticker Tests

    @Test("deleteSticker removes from context")
    func deleteSticker_removesFromContext() throws {
        let (dataManager, _) = try TestHelpers.createTestDataManager()
        let sticker = dataManager.saveSticker(
            imageData: TestFixtures.createTestImageData(),
            prompt: "test"
        )

        // Verify exists
        #expect(dataManager.fetchRecentStickers(limit: 10).count == 1)

        dataManager.deleteSticker(sticker)

        // Verify deleted
        #expect(dataManager.fetchRecentStickers(limit: 10).isEmpty)
    }

    @Test("deleteStickers removes multiple stickers")
    func deleteStickers_removesMultiple() throws {
        let (dataManager, _) = try TestHelpers.createTestDataManager()

        let stickers = (0..<5).map { i in
            dataManager.saveSticker(
                imageData: TestFixtures.createTestImageData(),
                prompt: "test\(i)"
            )
        }

        // Verify all exist
        #expect(dataManager.fetchRecentStickers(limit: 10).count == 5)

        // Delete first 3
        dataManager.deleteStickers(Array(stickers[0..<3]))

        // Verify 2 remain
        #expect(dataManager.fetchRecentStickers(limit: 10).count == 2)
    }

    // MARK: - Favorite Tests

    @Test("toggleFavorite toggles state")
    func toggleFavorite_togglesState() throws {
        let (dataManager, _) = try TestHelpers.createTestDataManager()
        let sticker = dataManager.saveSticker(
            imageData: TestFixtures.createTestImageData(),
            prompt: "test"
        )

        #expect(sticker.isFavorite == false)

        dataManager.toggleFavorite(sticker)
        #expect(sticker.isFavorite == true)

        dataManager.toggleFavorite(sticker)
        #expect(sticker.isFavorite == false)
    }

    // MARK: - Tag Tests

    @Test("addTag appends tag to sticker")
    func addTag_appendsTag() throws {
        let (dataManager, _) = try TestHelpers.createTestDataManager()
        let sticker = dataManager.saveSticker(
            imageData: TestFixtures.createTestImageData(),
            prompt: "test"
        )

        dataManager.addTag("nature", to: sticker)

        #expect(sticker.tags.contains("nature"))
        #expect(sticker.tags.count == 1)
    }

    @Test("addTag prevents duplicates")
    func addTag_preventsDuplicates() throws {
        let (dataManager, _) = try TestHelpers.createTestDataManager()
        let sticker = dataManager.saveSticker(
            imageData: TestFixtures.createTestImageData(),
            prompt: "test"
        )

        dataManager.addTag("nature", to: sticker)
        dataManager.addTag("nature", to: sticker)
        dataManager.addTag("nature", to: sticker)

        #expect(sticker.tags.count == 1)
    }

    @Test("removeTag removes tag from sticker")
    func removeTag_removesTag() throws {
        let (dataManager, _) = try TestHelpers.createTestDataManager()
        let sticker = dataManager.saveSticker(
            imageData: TestFixtures.createTestImageData(),
            prompt: "test"
        )

        dataManager.addTag("tag1", to: sticker)
        dataManager.addTag("tag2", to: sticker)

        #expect(sticker.tags.count == 2)

        dataManager.removeTag("tag1", from: sticker)

        #expect(sticker.tags.count == 1)
        #expect(!sticker.tags.contains("tag1"))
        #expect(sticker.tags.contains("tag2"))
    }

    // MARK: - Fetch Tests

    @Test("fetchRecentStickers sorts by date descending")
    func fetchRecentStickers_sortsByDate() throws {
        let (dataManager, _) = try TestHelpers.createTestDataManager()

        // Create stickers with slight delay to ensure different timestamps
        let sticker1 = dataManager.saveSticker(
            imageData: TestFixtures.createTestImageData(),
            prompt: "first"
        )

        // Manually set older date
        sticker1.createdAt = Date().addingTimeInterval(-100)

        let sticker2 = dataManager.saveSticker(
            imageData: TestFixtures.createTestImageData(),
            prompt: "second"
        )

        let fetched = dataManager.fetchRecentStickers(limit: 10)

        #expect(fetched.count == 2)
        #expect(fetched[0].prompt == "second") // Most recent first
        #expect(fetched[1].prompt == "first")
    }

    @Test("fetchRecentStickers respects limit")
    func fetchRecentStickers_respectsLimit() throws {
        let (dataManager, _) = try TestHelpers.createTestDataManager()

        // Create 10 stickers
        for i in 0..<10 {
            _ = dataManager.saveSticker(
                imageData: TestFixtures.createTestImageData(),
                prompt: "test\(i)"
            )
        }

        let fetched = dataManager.fetchRecentStickers(limit: 3)

        #expect(fetched.count == 3)
    }

    @Test("fetchFavorites filters correctly")
    func fetchFavorites_filtersCorrectly() throws {
        let (dataManager, _) = try TestHelpers.createTestDataManager()

        let sticker1 = dataManager.saveSticker(
            imageData: TestFixtures.createTestImageData(),
            prompt: "favorite"
        )
        sticker1.isFavorite = true

        _ = dataManager.saveSticker(
            imageData: TestFixtures.createTestImageData(),
            prompt: "not favorite"
        )

        let favorites = dataManager.fetchFavorites()

        #expect(favorites.count == 1)
        #expect(favorites.first?.prompt == "favorite")
    }

    @Test("fetchFavorites returns empty when none")
    func fetchFavorites_returnsEmptyWhenNone() throws {
        let (dataManager, _) = try TestHelpers.createTestDataManager()

        _ = dataManager.saveSticker(
            imageData: TestFixtures.createTestImageData(),
            prompt: "test"
        )

        let favorites = dataManager.fetchFavorites()

        #expect(favorites.isEmpty)
    }

    @Test("fetchByPrompt matches prompt exactly")
    func fetchByPrompt_matchesPrompt() throws {
        let (dataManager, _) = try TestHelpers.createTestDataManager()

        _ = dataManager.saveSticker(
            imageData: TestFixtures.createTestImageData(),
            prompt: "cat"
        )

        _ = dataManager.saveSticker(
            imageData: TestFixtures.createTestImageData(),
            prompt: "dog"
        )

        _ = dataManager.saveSticker(
            imageData: TestFixtures.createTestImageData(),
            prompt: "cat"
        )

        let catStickers = dataManager.fetchByPrompt("cat")

        #expect(catStickers.count == 2)
        #expect(catStickers.allSatisfy { $0.prompt == "cat" })
    }

    @Test("fetchStickerCount returns correct count")
    func fetchStickerCount_returnsCorrectCount() throws {
        let (dataManager, _) = try TestHelpers.createTestDataManager()

        #expect(dataManager.fetchStickerCount() == 0)

        for _ in 0..<5 {
            _ = dataManager.saveSticker(
                imageData: TestFixtures.createTestImageData(),
                prompt: "test"
            )
        }

        #expect(dataManager.fetchStickerCount() == 5)
    }

    // MARK: - Settings Tests

    @Test("getOrCreateSettings creates if not exists")
    func getOrCreateSettings_createsIfNotExists() throws {
        let (dataManager, _) = try TestHelpers.createTestDataManager()

        let settings = dataManager.getOrCreateSettings()

        #expect(settings.pollingInterval == 1.0) // Default value
    }

    @Test("getOrCreateSettings returns singleton")
    func getOrCreateSettings_returnsSingleton() throws {
        let (dataManager, _) = try TestHelpers.createTestDataManager()

        let settings1 = dataManager.getOrCreateSettings()
        settings1.pollingInterval = 5.0

        let settings2 = dataManager.getOrCreateSettings()

        #expect(settings1.id == settings2.id)
        #expect(settings2.pollingInterval == 5.0)
    }

    // MARK: - Collection Tests

    @Test("createCollection inserts collection")
    func createCollection_insertsCollection() throws {
        let (dataManager, _) = try TestHelpers.createTestDataManager()

        let collection = dataManager.createCollection(name: "My Collection")

        #expect(collection.name == "My Collection")

        let collections = dataManager.fetchCollections()
        #expect(collections.count == 1)
        #expect(collections.first?.id == collection.id)
    }

    @Test("fetchCollections returns all collections")
    func fetchCollections_returnsAll() throws {
        let (dataManager, _) = try TestHelpers.createTestDataManager()

        _ = dataManager.createCollection(name: "Collection 1")
        _ = dataManager.createCollection(name: "Collection 2")
        _ = dataManager.createCollection(name: "Collection 3")

        let collections = dataManager.fetchCollections()

        #expect(collections.count == 3)
    }

    @Test("addSticker to collection sets relationship")
    func addStickerToCollection_setsRelationship() throws {
        let (dataManager, _) = try TestHelpers.createTestDataManager()

        let collection = dataManager.createCollection(name: "Test")
        let sticker = dataManager.saveSticker(
            imageData: TestFixtures.createTestImageData(),
            prompt: "test"
        )

        dataManager.addSticker(sticker, to: collection)

        #expect(sticker.collection?.id == collection.id)
        #expect(collection.stickers.contains(where: { $0.id == sticker.id }))
    }

    @Test("removeFromCollection clears relationship")
    func removeFromCollection_clearsRelationship() throws {
        let (dataManager, _) = try TestHelpers.createTestDataManager()

        let collection = dataManager.createCollection(name: "Test")
        let sticker = dataManager.saveSticker(
            imageData: TestFixtures.createTestImageData(),
            prompt: "test"
        )

        dataManager.addSticker(sticker, to: collection)
        #expect(sticker.collection != nil)

        dataManager.removeFromCollection(sticker)

        #expect(sticker.collection == nil)
    }

    @Test("deleteCollection removes collection")
    func deleteCollection_removesCollection() throws {
        let (dataManager, _) = try TestHelpers.createTestDataManager()

        let collection = dataManager.createCollection(name: "Test")
        #expect(dataManager.fetchCollections().count == 1)

        dataManager.deleteCollection(collection)

        #expect(dataManager.fetchCollections().isEmpty)
    }
}
