//
//  Sticker.swift
//  meta-stickers
//

import Foundation
import SwiftData
import UIKit

@Model
final class Sticker {
    // Unique identifier
    var id: UUID

    // Image data stored externally for performance
    @Attribute(.externalStorage) var imageData: Data?

    // Small thumbnail for fast grid rendering (stored inline)
    var thumbnailData: Data?

    // Segmentation metadata
    var prompt: String
    var score: Float?
    var boundingBox: [Float]?

    // Timestamps
    var createdAt: Date

    // Organization
    var isFavorite: Bool
    var tags: [String]

    // Relationship to collection (optional)
    var collection: StickerCollection?

    init(
        imageData: Data?,
        prompt: String,
        score: Float? = nil,
        boundingBox: [Float]? = nil
    ) {
        self.id = UUID()
        self.imageData = imageData
        self.thumbnailData = Sticker.generateThumbnail(from: imageData)
        self.prompt = prompt
        self.score = score
        self.boundingBox = boundingBox
        self.createdAt = Date()
        self.isFavorite = false
        self.tags = []
    }

    // MARK: - Thumbnail Generation

    /// Generates a small thumbnail for efficient list rendering
    private static func generateThumbnail(from data: Data?, maxSize: CGFloat = 150) -> Data? {
        guard let data, let image = UIImage(data: data) else { return nil }

        let scale = min(maxSize / image.size.width, maxSize / image.size.height, 1.0)
        let newSize = CGSize(
            width: image.size.width * scale,
            height: image.size.height * scale
        )

        let renderer = UIGraphicsImageRenderer(size: newSize)
        let thumbnail = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }

        return thumbnail.pngData()
    }

    // MARK: - Convenience Properties

    /// Returns the thumbnail as UIImage for display
    var thumbnailImage: UIImage? {
        guard let data = thumbnailData else { return nil }
        return UIImage(data: data)
    }

    /// Returns the full image as UIImage for display
    var fullImage: UIImage? {
        guard let data = imageData else { return nil }
        return UIImage(data: data)
    }
}
