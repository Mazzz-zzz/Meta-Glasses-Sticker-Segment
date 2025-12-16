//
//  DataFlowTests.swift
//  meta-stickersTests
//

import Testing
import SwiftData
import UIKit
@testable import meta_stickers

@Suite("Data Flow Integration Tests")
@MainActor
struct DataFlowTests {

    // MARK: - Sticker Creation to Library Flow

    @Test("Sticker creation to library display flow")
    func stickerCreationToLibraryDisplay() throws {
        let (dataManager, _) = try TestHelpers.createTestDataManager()

        // 1. Create a sticker (simulating segmentation result)
        let imageData = TestFixtures.createTestImageData()
        let sticker = dataManager.saveSticker(
            imageData: imageData,
            prompt: "test object",
            score: 0.95,
            boundingBox: [10, 10, 90, 90]
        )

        // 2. Verify sticker was created
        #expect(sticker.id != nil)
        #expect(sticker.prompt == "test object")

        // 3. Fetch sticker (as library would)
        let recentStickers = dataManager.fetchRecentStickers(limit: 10)
        #expect(recentStickers.count == 1)
        #expect(recentStickers.first?.id == sticker.id)

        // 4. Verify thumbnail is available for display
        #expect(sticker.thumbnailImage != nil)
    }

    @Test("Multiple stickers are fetched in correct order")
    func multipleStickers_fetchedInCorrectOrder() throws {
        let (dataManager, _) = try TestHelpers.createTestDataManager()

        // Create multiple stickers with different timestamps
        var stickers: [Sticker] = []
        for i in 0..<5 {
            let sticker = dataManager.saveSticker(
                imageData: TestFixtures.createTestImageData(),
                prompt: "sticker\(i)"
            )
            // Set creation dates in order (oldest first)
            sticker.createdAt = Date().addingTimeInterval(Double(i) * 10)
            stickers.append(sticker)
        }

        // Fetch should return newest first
        let fetched = dataManager.fetchRecentStickers(limit: 10)
        #expect(fetched.count == 5)
        #expect(fetched.first?.prompt == "sticker4") // Most recent
        #expect(fetched.last?.prompt == "sticker0") // Oldest
    }

    // MARK: - Settings Persistence Flow

    @Test("Settings persistence across sessions")
    func settingsPersistence() throws {
        let (dataManager, _) = try TestHelpers.createTestDataManager()

        // 1. Get/create settings
        let settings = dataManager.getOrCreateSettings()

        // 2. Modify settings
        settings.pollingInterval = 2.5
        settings.currentPrompt = "custom prompt"
        settings.autoSaveStickers = false
        settings.streamQuality = "high"
        settings.streamFPS = 30

        // 3. Retrieve settings again (simulating app restart)
        let retrievedSettings = dataManager.getOrCreateSettings()

        // 4. Verify all settings persisted
        #expect(retrievedSettings.pollingInterval == 2.5)
        #expect(retrievedSettings.currentPrompt == "custom prompt")
        #expect(retrievedSettings.autoSaveStickers == false)
        #expect(retrievedSettings.streamQuality == "high")
        #expect(retrievedSettings.streamFPS == 30)

        // 5. Verify it's the same settings instance (singleton)
        #expect(retrievedSettings.id == settings.id)
    }

    // MARK: - Collection Management Flow

    @Test("Collection CRUD operations")
    func collectionCRUDOperations() throws {
        let (dataManager, _) = try TestHelpers.createTestDataManager()

        // CREATE
        let collection = dataManager.createCollection(name: "Nature")
        #expect(collection.name == "Nature")

        // READ
        let collections = dataManager.fetchCollections()
        #expect(collections.count == 1)
        #expect(collections.first?.name == "Nature")

        // UPDATE - Add stickers
        let sticker1 = dataManager.saveSticker(
            imageData: TestFixtures.createTestImageData(),
            prompt: "tree"
        )
        let sticker2 = dataManager.saveSticker(
            imageData: TestFixtures.createTestImageData(),
            prompt: "flower"
        )

        dataManager.addSticker(sticker1, to: collection)
        dataManager.addSticker(sticker2, to: collection)

        #expect(collection.stickerCount == 2)
        #expect(sticker1.collection?.id == collection.id)
        #expect(sticker2.collection?.id == collection.id)

        // UPDATE - Rename (direct property modification)
        collection.name = "Outdoor"
        #expect(collection.name == "Outdoor")

        // DELETE
        dataManager.deleteCollection(collection)
        #expect(dataManager.fetchCollections().isEmpty)

        // Verify stickers still exist (nullify delete rule)
        let remainingStickers = dataManager.fetchRecentStickers(limit: 10)
        #expect(remainingStickers.count == 2)
    }

    // MARK: - Favorite Flow

    @Test("Favorite stickers flow")
    func favoriteStickersFlow() throws {
        let (dataManager, _) = try TestHelpers.createTestDataManager()

        // Create stickers
        let sticker1 = dataManager.saveSticker(
            imageData: TestFixtures.createTestImageData(),
            prompt: "cat"
        )
        let sticker2 = dataManager.saveSticker(
            imageData: TestFixtures.createTestImageData(),
            prompt: "dog"
        )
        let sticker3 = dataManager.saveSticker(
            imageData: TestFixtures.createTestImageData(),
            prompt: "bird"
        )

        // Mark some as favorites
        dataManager.toggleFavorite(sticker1)
        dataManager.toggleFavorite(sticker3)

        // Fetch favorites
        let favorites = dataManager.fetchFavorites()

        #expect(favorites.count == 2)
        #expect(favorites.contains(where: { $0.id == sticker1.id }))
        #expect(favorites.contains(where: { $0.id == sticker3.id }))
        #expect(!favorites.contains(where: { $0.id == sticker2.id }))
    }

    // MARK: - Tag Management Flow

    @Test("Tag management flow")
    func tagManagementFlow() throws {
        let (dataManager, _) = try TestHelpers.createTestDataManager()

        let sticker = dataManager.saveSticker(
            imageData: TestFixtures.createTestImageData(),
            prompt: "landscape"
        )

        // Add tags
        dataManager.addTag("nature", to: sticker)
        dataManager.addTag("outdoor", to: sticker)
        dataManager.addTag("scenic", to: sticker)

        #expect(sticker.tags.count == 3)

        // Verify no duplicates
        dataManager.addTag("nature", to: sticker)
        #expect(sticker.tags.count == 3)

        // Remove tag
        dataManager.removeTag("outdoor", from: sticker)
        #expect(sticker.tags.count == 2)
        #expect(!sticker.tags.contains("outdoor"))
    }

    // MARK: - Search by Prompt Flow

    @Test("Search by prompt flow")
    func searchByPromptFlow() throws {
        let (dataManager, _) = try TestHelpers.createTestDataManager()

        // Create stickers with different prompts
        _ = dataManager.saveSticker(imageData: TestFixtures.createTestImageData(), prompt: "cat")
        _ = dataManager.saveSticker(imageData: TestFixtures.createTestImageData(), prompt: "dog")
        _ = dataManager.saveSticker(imageData: TestFixtures.createTestImageData(), prompt: "cat")
        _ = dataManager.saveSticker(imageData: TestFixtures.createTestImageData(), prompt: "cat")
        _ = dataManager.saveSticker(imageData: TestFixtures.createTestImageData(), prompt: "bird")

        // Search by prompt
        let catStickers = dataManager.fetchByPrompt("cat")
        let dogStickers = dataManager.fetchByPrompt("dog")
        let birdStickers = dataManager.fetchByPrompt("bird")
        let fishStickers = dataManager.fetchByPrompt("fish")

        #expect(catStickers.count == 3)
        #expect(dogStickers.count == 1)
        #expect(birdStickers.count == 1)
        #expect(fishStickers.isEmpty)
    }

    // MARK: - Batch Delete Flow

    @Test("Batch delete flow")
    func batchDeleteFlow() throws {
        let (dataManager, _) = try TestHelpers.createTestDataManager()

        // Create stickers
        var stickers: [Sticker] = []
        for i in 0..<10 {
            stickers.append(dataManager.saveSticker(
                imageData: TestFixtures.createTestImageData(),
                prompt: "sticker\(i)"
            ))
        }

        #expect(dataManager.fetchStickerCount() == 10)

        // Delete subset
        dataManager.deleteStickers(Array(stickers[0..<5]))

        #expect(dataManager.fetchStickerCount() == 5)

        // Delete remaining
        dataManager.deleteStickers(Array(stickers[5..<10]))

        #expect(dataManager.fetchStickerCount() == 0)
    }
}
