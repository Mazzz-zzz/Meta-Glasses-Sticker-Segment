//
//  StickerDataManager.swift
//  meta-stickers
//

import Foundation
import SwiftData
import UIKit

@MainActor
class StickerDataManager {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Sticker Operations

    /// Saves a new sticker to the database
    func saveSticker(
        imageData: Data,
        prompt: String,
        score: Float? = nil,
        boundingBox: [Float]? = nil
    ) -> Sticker {
        let sticker = Sticker(
            imageData: imageData,
            prompt: prompt,
            score: score,
            boundingBox: boundingBox
        )
        modelContext.insert(sticker)
        print("[StickerDB] Saved sticker: \(sticker.id)")
        return sticker
    }

    /// Saves a sticker from UIImage
    func saveSticker(
        image: UIImage,
        prompt: String,
        score: Float? = nil,
        boundingBox: [Float]? = nil
    ) -> Sticker? {
        guard let imageData = image.pngData() else {
            print("[StickerDB] Failed to convert image to data")
            return nil
        }
        return saveSticker(
            imageData: imageData,
            prompt: prompt,
            score: score,
            boundingBox: boundingBox
        )
    }

    /// Deletes a sticker from the database
    func deleteSticker(_ sticker: Sticker) {
        modelContext.delete(sticker)
        print("[StickerDB] Deleted sticker: \(sticker.id)")
    }

    /// Deletes multiple stickers
    func deleteStickers(_ stickers: [Sticker]) {
        for sticker in stickers {
            modelContext.delete(sticker)
        }
        print("[StickerDB] Deleted \(stickers.count) stickers")
    }

    /// Toggles favorite status for a sticker
    func toggleFavorite(_ sticker: Sticker) {
        sticker.isFavorite.toggle()
        print("[StickerDB] Toggled favorite for \(sticker.id): \(sticker.isFavorite)")
    }

    /// Adds a tag to a sticker
    func addTag(_ tag: String, to sticker: Sticker) {
        if !sticker.tags.contains(tag) {
            sticker.tags.append(tag)
        }
    }

    /// Removes a tag from a sticker
    func removeTag(_ tag: String, from sticker: Sticker) {
        sticker.tags.removeAll { $0 == tag }
    }

    // MARK: - Fetch Operations

    /// Fetches recent stickers, sorted by creation date (newest first)
    func fetchRecentStickers(limit: Int = 50) -> [Sticker] {
        var descriptor = FetchDescriptor<Sticker>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit

        do {
            return try modelContext.fetch(descriptor)
        } catch {
            print("[StickerDB] Error fetching recent stickers: \(error)")
            return []
        }
    }

    /// Fetches all favorite stickers
    func fetchFavorites() -> [Sticker] {
        let predicate = #Predicate<Sticker> { sticker in
            sticker.isFavorite == true
        }
        let descriptor = FetchDescriptor<Sticker>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )

        do {
            return try modelContext.fetch(descriptor)
        } catch {
            print("[StickerDB] Error fetching favorites: \(error)")
            return []
        }
    }

    /// Fetches stickers by prompt
    func fetchByPrompt(_ prompt: String) -> [Sticker] {
        let predicate = #Predicate<Sticker> { sticker in
            sticker.prompt == prompt
        }
        let descriptor = FetchDescriptor<Sticker>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )

        do {
            return try modelContext.fetch(descriptor)
        } catch {
            print("[StickerDB] Error fetching by prompt: \(error)")
            return []
        }
    }

    /// Fetches total sticker count
    func fetchStickerCount() -> Int {
        let descriptor = FetchDescriptor<Sticker>()
        do {
            return try modelContext.fetchCount(descriptor)
        } catch {
            print("[StickerDB] Error fetching count: \(error)")
            return 0
        }
    }

    // MARK: - Settings Operations

    /// Gets or creates the singleton AppSettings
    func getOrCreateSettings() -> AppSettings {
        let descriptor = FetchDescriptor<AppSettings>()

        do {
            if let existing = try modelContext.fetch(descriptor).first {
                return existing
            }
        } catch {
            print("[StickerDB] Error fetching settings: \(error)")
        }

        // Create new settings if none exist
        let settings = AppSettings()
        modelContext.insert(settings)
        print("[StickerDB] Created new AppSettings")
        return settings
    }

    // MARK: - Collection Operations

    /// Creates a new sticker collection
    func createCollection(name: String) -> StickerCollection {
        let collection = StickerCollection(name: name)
        modelContext.insert(collection)
        print("[StickerDB] Created collection: \(name)")
        return collection
    }

    /// Fetches all collections
    func fetchCollections() -> [StickerCollection] {
        let descriptor = FetchDescriptor<StickerCollection>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )

        do {
            return try modelContext.fetch(descriptor)
        } catch {
            print("[StickerDB] Error fetching collections: \(error)")
            return []
        }
    }

    /// Adds a sticker to a collection
    func addSticker(_ sticker: Sticker, to collection: StickerCollection) {
        sticker.collection = collection
        if !collection.stickers.contains(where: { $0.id == sticker.id }) {
            collection.stickers.append(sticker)
        }
    }

    /// Removes a sticker from its collection
    func removeFromCollection(_ sticker: Sticker) {
        sticker.collection?.stickers.removeAll { $0.id == sticker.id }
        sticker.collection = nil
    }

    /// Deletes a collection (stickers are preserved)
    func deleteCollection(_ collection: StickerCollection) {
        modelContext.delete(collection)
        print("[StickerDB] Deleted collection: \(collection.name)")
    }
}
