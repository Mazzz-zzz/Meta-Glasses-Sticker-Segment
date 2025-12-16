//
//  AppSettings.swift
//  meta-stickers
//

import Foundation
import SwiftData

@Model
final class AppSettings {
    // Unique identifier (singleton pattern - only one record)
    var id: UUID

    // MARK: - Segmentation Settings

    /// Whether SAM3 segmentation is enabled
    var segmentationEnabled: Bool

    /// Polling interval in seconds
    var pollingInterval: Double

    /// Current segmentation prompt
    var currentPrompt: String

    /// Segmentation source: "videoFrame" or "photoCapture"
    var segmentationSource: String

    // MARK: - Stream Settings

    /// Stream quality: "low", "medium", "high"
    var streamQuality: String

    /// Stream frames per second
    var streamFPS: Int

    // MARK: - UI Preferences

    /// Number of columns in sticker grid
    var gridColumns: Int

    /// Automatically save generated stickers to library
    var autoSaveStickers: Bool

    /// Show checkerboard background for transparency
    var showTransparencyGrid: Bool

    init() {
        self.id = UUID()

        // Segmentation defaults
        self.segmentationEnabled = false
        self.pollingInterval = 1.0
        self.currentPrompt = "object"
        self.segmentationSource = "videoFrame"

        // Stream defaults
        self.streamQuality = "low"
        self.streamFPS = 24

        // UI defaults
        self.gridColumns = 3
        self.autoSaveStickers = true
        self.showTransparencyGrid = true
    }

    // MARK: - Enums for Type Safety

    enum SegmentationSource: String, CaseIterable {
        case videoFrame = "videoFrame"
        case photoCapture = "photoCapture"

        var displayName: String {
            switch self {
            case .videoFrame: return "Video Frame (Silent)"
            case .photoCapture: return "Photo Capture (Higher Quality)"
            }
        }
    }

    enum StreamQuality: String, CaseIterable {
        case low = "low"
        case medium = "medium"
        case high = "high"

        var displayName: String {
            rawValue.capitalized
        }
    }
}
