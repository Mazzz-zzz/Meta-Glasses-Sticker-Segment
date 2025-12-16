//
//  StickerCollection.swift
//  meta-stickers
//

import Foundation
import SwiftData

@Model
final class StickerCollection {
    // Unique identifier
    var id: UUID

    // Collection metadata
    var name: String
    var createdAt: Date

    // Relationship to stickers
    @Relationship(deleteRule: .nullify, inverse: \Sticker.collection)
    var stickers: [Sticker]

    init(name: String) {
        self.id = UUID()
        self.name = name
        self.createdAt = Date()
        self.stickers = []
    }

    // MARK: - Convenience Properties

    /// Number of stickers in the collection
    var stickerCount: Int {
        stickers.count
    }

    /// Preview stickers for collection thumbnail (first 4)
    var previewStickers: [Sticker] {
        Array(stickers.prefix(4))
    }
}
