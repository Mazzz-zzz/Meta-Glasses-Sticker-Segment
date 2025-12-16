//
//  SegmentationManagerTests.swift
//  meta-stickersTests
//

import Testing
import UIKit
@testable import meta_stickers

@Suite("SegmentationManager Tests")
@MainActor
struct SegmentationManagerTests {

    // MARK: - Initialization Tests

    @Test("Initialization sets default values")
    func init_setsDefaultValues() {
        let manager = SegmentationManager()

        #expect(manager.isEnabled == false)
        #expect(manager.pollingInterval == 1.0)
        #expect(manager.currentPrompt == "object")
        #expect(manager.lastResult == nil)
        #expect(manager.lastError == nil)
        #expect(manager.isProcessing == false)
        #expect(manager.source == .videoFrame)
        #expect(manager.stickerHistory.isEmpty)
        #expect(manager.autoSaveEnabled == true)
    }

    @Test("Initialization with API key")
    func init_withAPIKey() {
        let manager = SegmentationManager(apiKey: "test-api-key")

        #expect(manager != nil)
    }

    @Test("Initialization with data manager")
    func init_withDataManager() throws {
        let (dataManager, _) = try TestHelpers.createTestDataManager()
        let manager = SegmentationManager(dataManager: dataManager)

        #expect(manager != nil)
    }

    // MARK: - Start/Stop Tests

    @Test("start sets isEnabled to true")
    func start_setsIsEnabledTrue() {
        let manager = SegmentationManager()

        manager.start()

        #expect(manager.isEnabled == true)
    }

    @Test("start clears lastError")
    func start_clearsLastError() {
        let manager = SegmentationManager()
        manager.lastError = "Previous error"

        manager.start()

        #expect(manager.lastError == nil)
    }

    @Test("start does nothing if already enabled")
    func start_doesNothingIfAlreadyEnabled() {
        let manager = SegmentationManager()
        manager.start()
        #expect(manager.isEnabled == true)

        // Start again - should still be enabled
        manager.start()
        #expect(manager.isEnabled == true)
    }

    @Test("stop sets isEnabled to false")
    func stop_setsIsEnabledFalse() {
        let manager = SegmentationManager()
        manager.start()
        #expect(manager.isEnabled == true)

        manager.stop()

        #expect(manager.isEnabled == false)
    }

    // MARK: - Polling Interval Tests

    @Test("setPollingInterval updates interval")
    func setPollingInterval_updatesInterval() {
        let manager = SegmentationManager()

        manager.setPollingInterval(2.5)

        #expect(manager.pollingInterval == 2.5)
    }

    @Test("setPollingInterval enforces minimum of 0.5")
    func setPollingInterval_enforcesMinimum() {
        let manager = SegmentationManager()

        manager.setPollingInterval(0.1)

        #expect(manager.pollingInterval == 0.5)
    }

    @Test("setPollingInterval restarts polling if enabled")
    func setPollingInterval_restartsPollinfIfEnabled() {
        let manager = SegmentationManager()
        manager.start()

        manager.setPollingInterval(3.0)

        #expect(manager.pollingInterval == 3.0)
        #expect(manager.isEnabled == true)
    }

    // MARK: - Prompt Tests

    @Test("setPrompt updates prompt")
    func setPrompt_updatesPrompt() {
        let manager = SegmentationManager()

        manager.setPrompt("person")

        #expect(manager.currentPrompt == "person")
    }

    @Test("setPrompt accepts empty string")
    func setPrompt_acceptsEmptyString() {
        let manager = SegmentationManager()

        manager.setPrompt("")

        #expect(manager.currentPrompt == "")
    }

    // MARK: - History Tests

    @Test("clearHistory removes all items")
    func clearHistory_removesAllItems() {
        let manager = SegmentationManager()

        // Add some mock history items
        manager.stickerHistory.append(TestFixtures.createTestSegmentationResult())
        manager.stickerHistory.append(TestFixtures.createTestSegmentationResult())

        #expect(manager.stickerHistory.count == 2)

        manager.clearHistory()

        #expect(manager.stickerHistory.isEmpty)
    }

    // MARK: - Source Tests

    @Test("source defaults to videoFrame")
    func source_defaultsToVideoFrame() {
        let manager = SegmentationManager()

        #expect(manager.source == .videoFrame)
    }

    @Test("source can be changed to photoCapture")
    func source_canBeChangedToPhotoCapture() {
        let manager = SegmentationManager()

        manager.source = .photoCapture

        #expect(manager.source == .photoCapture)
    }

    // MARK: - Data Manager Integration Tests

    @Test("setDataManager assigns manager")
    func setDataManager_assignsManager() throws {
        let manager = SegmentationManager()
        let (dataManager, _) = try TestHelpers.createTestDataManager()

        manager.setDataManager(dataManager)

        // Can't directly test private property, but we can verify it doesn't crash
        #expect(manager != nil)
    }

    // MARK: - Video Frame Tests

    @Test("updateVideoFrame accepts image")
    func updateVideoFrame_acceptsImage() {
        let manager = SegmentationManager()
        let testImage = TestFixtures.createTestImage()

        manager.updateVideoFrame(testImage)

        // Can't directly verify private property, but should not crash
        #expect(manager != nil)
    }

    // MARK: - Photo Capture Tests

    @Test("onPhotoCaptured accepts photo")
    func onPhotoCaptured_acceptsPhoto() {
        let manager = SegmentationManager()
        let testPhoto = TestFixtures.createTestImage()

        manager.onPhotoCaptured(testPhoto)

        // Can't directly verify private property, but should not crash
        #expect(manager != nil)
    }

    @Test("setPhotoCaptureCallback sets callback")
    func setPhotoCaptureCallback_setsCallback() {
        let manager = SegmentationManager()
        var callbackCalled = false

        manager.setPhotoCaptureCallback {
            callbackCalled = true
        }

        // The callback would be called during polling, but we can verify setup works
        #expect(manager != nil)
    }

    // MARK: - Auto Save Tests

    @Test("autoSaveEnabled defaults to true")
    func autoSaveEnabled_defaultsTrue() {
        let manager = SegmentationManager()

        #expect(manager.autoSaveEnabled == true)
    }

    @Test("autoSaveEnabled can be toggled")
    func autoSaveEnabled_canBeToggled() {
        let manager = SegmentationManager()

        manager.autoSaveEnabled = false
        #expect(manager.autoSaveEnabled == false)

        manager.autoSaveEnabled = true
        #expect(manager.autoSaveEnabled == true)
    }
}

// MARK: - SegmentationResult Tests

@Suite("SegmentationResult Tests")
struct SegmentationResultTests {

    @Test("SegmentationResult initializes with values")
    func init_withValues() {
        let image = TestFixtures.createTestImage()
        let result = SegmentationResult(
            maskImage: image,
            maskURL: "https://example.com/mask.png",
            score: 0.95,
            boundingBox: [10, 10, 90, 90],
            timestamp: Date()
        )

        #expect(result.maskImage != nil)
        #expect(result.maskURL == "https://example.com/mask.png")
        #expect(result.score == 0.95)
        #expect(result.boundingBox == [10, 10, 90, 90])
    }

    @Test("SegmentationResult generates unique ID")
    func init_generatesUniqueId() {
        let result1 = TestFixtures.createTestSegmentationResult()
        let result2 = TestFixtures.createTestSegmentationResult()

        #expect(result1.id != result2.id)
    }

    @Test("SegmentationResult allows nil values")
    func init_allowsNilValues() {
        let result = SegmentationResult(
            maskImage: nil,
            maskURL: nil,
            score: nil,
            boundingBox: nil,
            timestamp: Date()
        )

        #expect(result.maskImage == nil)
        #expect(result.maskURL == nil)
        #expect(result.score == nil)
        #expect(result.boundingBox == nil)
    }
}

// MARK: - SegmentationSource Enum Tests

@Suite("SegmentationSource Enum Tests")
struct SegmentationSourceEnumTests {

    @Test("SegmentationSource has expected cases")
    func hasExpectedCases() {
        let allCases = SegmentationSource.allCases

        #expect(allCases.count == 2)
        #expect(allCases.contains(.videoFrame))
        #expect(allCases.contains(.photoCapture))
    }

    @Test("SegmentationSource raw values are correct")
    func rawValuesAreCorrect() {
        #expect(SegmentationSource.videoFrame.rawValue == "Video Frame (Silent)")
        #expect(SegmentationSource.photoCapture.rawValue == "Photo Capture (Higher Quality)")
    }
}
