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

    // MARK: - Sticker Style Settings

    /// Selected sticker style preset
    var stickerStyle: String = "default"

    /// Border width (0 = no border)
    var borderWidth: Double = 0.0

    /// Border color as hex string
    var borderColor: String = "#FFFFFF"

    /// Whether to add shadow effect
    var shadowEnabled: Bool = true

    /// Shadow opacity (0-1)
    var shadowOpacity: Double = 0.3

    /// Corner rounding amount (0 = sharp, 1 = full round)
    var cornerRounding: Double = 0.0

    /// Background style: "transparent", "white", "gradient"
    var backgroundStyle: String = "transparent"

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

        // Sticker style defaults
        self.stickerStyle = "default"
        self.borderWidth = 0.0
        self.borderColor = "#FFFFFF"
        self.shadowEnabled = true
        self.shadowOpacity = 0.3
        self.cornerRounding = 0.0
        self.backgroundStyle = "transparent"
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

    enum StickerStyle: String, CaseIterable {
        case `default` = "default"
        case outlined = "outlined"
        case cartoon = "cartoon"
        case minimal = "minimal"
        case glossy = "glossy"
        case vintage = "vintage"

        var displayName: String {
            switch self {
            case .default: return "Default"
            case .outlined: return "Outlined"
            case .cartoon: return "Cartoon"
            case .minimal: return "Minimal"
            case .glossy: return "Glossy"
            case .vintage: return "Vintage"
            }
        }

        var description: String {
            switch self {
            case .default: return "Clean cutout with subtle shadow"
            case .outlined: return "White border around the sticker"
            case .cartoon: return "Bold colors with thick outline"
            case .minimal: return "Simple, no effects"
            case .glossy: return "Shiny highlight effect"
            case .vintage: return "Faded colors with worn edges"
            }
        }
    }

    enum BackgroundStyle: String, CaseIterable {
        case transparent = "transparent"
        case white = "white"
        case gradient = "gradient"

        var displayName: String {
            rawValue.capitalized
        }
    }
}
