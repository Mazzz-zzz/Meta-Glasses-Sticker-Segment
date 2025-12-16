//
//  TestHelpers.swift
//  meta-stickersTests
//

import Foundation
import SwiftData
import UIKit
@testable import meta_stickers

/// Helper utilities for SwiftData testing
@MainActor
enum TestHelpers {

    /// Creates an in-memory ModelContainer for isolated testing
    static func createInMemoryModelContainer() throws -> ModelContainer {
        let schema = Schema([
            Sticker.self,
            StickerCollection.self,
            AppSettings.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    /// Creates a StickerDataManager with an in-memory context for testing
    static func createTestDataManager() throws -> (StickerDataManager, ModelContext) {
        let container = try createInMemoryModelContainer()
        let context = ModelContext(container)
        let dataManager = StickerDataManager(modelContext: context)
        return (dataManager, context)
    }

    /// Creates a ModelContext for testing
    static func createTestModelContext() throws -> ModelContext {
        let container = try createInMemoryModelContainer()
        return ModelContext(container)
    }

    /// Resets the model context by deleting all entities
    static func resetContext(_ context: ModelContext) throws {
        try context.delete(model: Sticker.self)
        try context.delete(model: StickerCollection.self)
        try context.delete(model: AppSettings.self)
    }
}
