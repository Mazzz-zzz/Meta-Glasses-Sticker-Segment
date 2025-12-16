//
//  AppSettingsTests.swift
//  meta-stickersTests
//

import Testing
import SwiftData
@testable import meta_stickers

@Suite("AppSettings Model Tests")
struct AppSettingsTests {

    // MARK: - Initialization Tests

    @Test("Default initialization sets expected values")
    func init_setsDefaultSettings() {
        let settings = AppSettings()

        // Segmentation defaults
        #expect(settings.segmentationEnabled == false)
        #expect(settings.pollingInterval == 1.0)
        #expect(settings.currentPrompt == "object")
        #expect(settings.segmentationSource == "videoFrame")

        // Stream defaults
        #expect(settings.streamQuality == "low")
        #expect(settings.streamFPS == 24)

        // UI defaults
        #expect(settings.gridColumns == 3)
        #expect(settings.autoSaveStickers == true)
        #expect(settings.showTransparencyGrid == true)
    }

    @Test("Initialization generates unique ID")
    func init_generatesUniqueId() {
        let settings1 = AppSettings()
        let settings2 = AppSettings()

        #expect(settings1.id != settings2.id)
    }

    // MARK: - Polling Interval Tests

    @Test("Polling interval default is 1.0 seconds")
    func pollingInterval_defaultValue() {
        let settings = AppSettings()

        #expect(settings.pollingInterval == 1.0)
    }

    @Test("Polling interval can be modified")
    func pollingInterval_canBeModified() {
        let settings = AppSettings()

        settings.pollingInterval = 2.5

        #expect(settings.pollingInterval == 2.5)
    }

    // MARK: - Current Prompt Tests

    @Test("Current prompt default is 'object'")
    func currentPrompt_defaultValue() {
        let settings = AppSettings()

        #expect(settings.currentPrompt == "object")
    }

    @Test("Current prompt can be modified")
    func currentPrompt_canBeModified() {
        let settings = AppSettings()

        settings.currentPrompt = "person"

        #expect(settings.currentPrompt == "person")
    }

    // MARK: - Auto Save Tests

    @Test("Auto save stickers defaults to true")
    func autoSaveStickers_defaultTrue() {
        let settings = AppSettings()

        #expect(settings.autoSaveStickers == true)
    }

    @Test("Auto save stickers can be toggled")
    func autoSaveStickers_canBeToggled() {
        let settings = AppSettings()

        settings.autoSaveStickers = false
        #expect(settings.autoSaveStickers == false)

        settings.autoSaveStickers = true
        #expect(settings.autoSaveStickers == true)
    }

    // MARK: - Segmentation Enabled Tests

    @Test("Segmentation enabled defaults to false")
    func segmentationEnabled_defaultFalse() {
        let settings = AppSettings()

        #expect(settings.segmentationEnabled == false)
    }

    @Test("Segmentation enabled can be toggled")
    func segmentationEnabled_canBeToggled() {
        let settings = AppSettings()

        settings.segmentationEnabled = true
        #expect(settings.segmentationEnabled == true)
    }

    // MARK: - Segmentation Source Tests

    @Test("Segmentation source default is videoFrame")
    func segmentationSource_defaultVideoFrame() {
        let settings = AppSettings()

        #expect(settings.segmentationSource == "videoFrame")
    }

    @Test("Segmentation source can be changed")
    func segmentationSource_canBeChanged() {
        let settings = AppSettings()

        settings.segmentationSource = "photoCapture"

        #expect(settings.segmentationSource == "photoCapture")
    }

    // MARK: - Stream Quality Tests

    @Test("Stream quality default is low")
    func streamQuality_defaultLow() {
        let settings = AppSettings()

        #expect(settings.streamQuality == "low")
    }

    @Test("Stream quality can be changed")
    func streamQuality_canBeChanged() {
        let settings = AppSettings()

        settings.streamQuality = "high"

        #expect(settings.streamQuality == "high")
    }

    // MARK: - Stream FPS Tests

    @Test("Stream FPS default is 24")
    func streamFPS_default24() {
        let settings = AppSettings()

        #expect(settings.streamFPS == 24)
    }

    @Test("Stream FPS can be changed")
    func streamFPS_canBeChanged() {
        let settings = AppSettings()

        settings.streamFPS = 30

        #expect(settings.streamFPS == 30)
    }

    // MARK: - Grid Columns Tests

    @Test("Grid columns default is 3")
    func gridColumns_default3() {
        let settings = AppSettings()

        #expect(settings.gridColumns == 3)
    }

    @Test("Grid columns can be changed")
    func gridColumns_canBeChanged() {
        let settings = AppSettings()

        settings.gridColumns = 4

        #expect(settings.gridColumns == 4)
    }

    // MARK: - Transparency Grid Tests

    @Test("Show transparency grid defaults to true")
    func showTransparencyGrid_defaultTrue() {
        let settings = AppSettings()

        #expect(settings.showTransparencyGrid == true)
    }

    @Test("Show transparency grid can be toggled")
    func showTransparencyGrid_canBeToggled() {
        let settings = AppSettings()

        settings.showTransparencyGrid = false
        #expect(settings.showTransparencyGrid == false)
    }

    // MARK: - Enum Tests

    @Test("SegmentationSource enum has expected cases")
    func segmentationSourceEnum_hasExpectedCases() {
        let allCases = AppSettings.SegmentationSource.allCases

        #expect(allCases.count == 2)
        #expect(allCases.contains(.videoFrame))
        #expect(allCases.contains(.photoCapture))
    }

    @Test("SegmentationSource raw values are correct")
    func segmentationSourceEnum_rawValues() {
        #expect(AppSettings.SegmentationSource.videoFrame.rawValue == "videoFrame")
        #expect(AppSettings.SegmentationSource.photoCapture.rawValue == "photoCapture")
    }

    @Test("SegmentationSource displayNames are correct")
    func segmentationSourceEnum_displayNames() {
        #expect(AppSettings.SegmentationSource.videoFrame.displayName == "Video Frame (Silent)")
        #expect(AppSettings.SegmentationSource.photoCapture.displayName == "Photo Capture (Higher Quality)")
    }

    @Test("StreamQuality enum has expected cases")
    func streamQualityEnum_hasExpectedCases() {
        let allCases = AppSettings.StreamQuality.allCases

        #expect(allCases.count == 3)
        #expect(allCases.contains(.low))
        #expect(allCases.contains(.medium))
        #expect(allCases.contains(.high))
    }

    @Test("StreamQuality raw values are correct")
    func streamQualityEnum_rawValues() {
        #expect(AppSettings.StreamQuality.low.rawValue == "low")
        #expect(AppSettings.StreamQuality.medium.rawValue == "medium")
        #expect(AppSettings.StreamQuality.high.rawValue == "high")
    }

    @Test("StreamQuality displayNames are capitalized")
    func streamQualityEnum_displayNames() {
        #expect(AppSettings.StreamQuality.low.displayName == "Low")
        #expect(AppSettings.StreamQuality.medium.displayName == "Medium")
        #expect(AppSettings.StreamQuality.high.displayName == "High")
    }
}
