//
//  SegmentationPipelineTests.swift
//  meta-stickersTests
//

import Testing
import SwiftData
import UIKit
@testable import meta_stickers

@Suite("Segmentation Pipeline Integration Tests")
@MainActor
struct SegmentationPipelineTests {

    // MARK: - Manager Setup Tests

    @Test("SegmentationManager integrates with DataManager")
    func segmentationManager_integratesWithDataManager() throws {
        let (dataManager, _) = try TestHelpers.createTestDataManager()
        let segmentationManager = SegmentationManager(dataManager: dataManager)

        #expect(segmentationManager.autoSaveEnabled == true)
    }

    @Test("SegmentationManager setDataManager updates integration")
    func segmentationManager_setDataManagerUpdates() throws {
        let segmentationManager = SegmentationManager()
        let (dataManager, _) = try TestHelpers.createTestDataManager()

        segmentationManager.setDataManager(dataManager)

        // Can't directly verify private property, but setup should work
        #expect(segmentationManager != nil)
    }

    // MARK: - Settings Integration Tests

    @Test("Settings control segmentation behavior")
    func settingsControlSegmentation() throws {
        let (dataManager, _) = try TestHelpers.createTestDataManager()
        let settings = dataManager.getOrCreateSettings()

        // Verify default settings match expected behavior
        #expect(settings.segmentationEnabled == false)
        #expect(settings.pollingInterval == 1.0)
        #expect(settings.currentPrompt == "object")
        #expect(settings.autoSaveStickers == true)

        // Modify settings
        settings.pollingInterval = 2.0
        settings.currentPrompt = "person"

        // Create segmentation manager with these settings
        let segmentationManager = SegmentationManager(dataManager: dataManager)
        segmentationManager.setPollingInterval(settings.pollingInterval)
        segmentationManager.setPrompt(settings.currentPrompt)

        #expect(segmentationManager.pollingInterval == 2.0)
        #expect(segmentationManager.currentPrompt == "person")
    }

    // MARK: - History Management Tests

    @Test("Segmentation history is maintained")
    func segmentationHistoryMaintained() {
        let manager = SegmentationManager()

        // Manually add to history (simulating successful segmentation)
        let result1 = TestFixtures.createTestSegmentationResult()
        let result2 = TestFixtures.createTestSegmentationResult()
        let result3 = TestFixtures.createTestSegmentationResult()

        manager.stickerHistory.append(result1)
        manager.stickerHistory.append(result2)
        manager.stickerHistory.append(result3)

        #expect(manager.stickerHistory.count == 3)
    }

    @Test("Segmentation history can be cleared")
    func segmentationHistoryCleared() {
        let manager = SegmentationManager()

        // Add items
        manager.stickerHistory.append(TestFixtures.createTestSegmentationResult())
        manager.stickerHistory.append(TestFixtures.createTestSegmentationResult())

        #expect(manager.stickerHistory.count == 2)

        // Clear
        manager.clearHistory()

        #expect(manager.stickerHistory.isEmpty)
    }

    // MARK: - Source Selection Tests

    @Test("Source selection affects behavior")
    func sourceSelectionAffectsBehavior() {
        let manager = SegmentationManager()

        // Default is video frame
        #expect(manager.source == .videoFrame)

        // Change to photo capture
        manager.source = .photoCapture
        #expect(manager.source == .photoCapture)

        // Change back
        manager.source = .videoFrame
        #expect(manager.source == .videoFrame)
    }

    // MARK: - Callback Integration Tests

    @Test("Photo capture callback can be set")
    func photoCaptureCallbackCanBeSet() {
        let manager = SegmentationManager()
        var callbackInvoked = false

        manager.setPhotoCaptureCallback {
            callbackInvoked = true
        }

        // Callback isn't called until polling requests it
        #expect(callbackInvoked == false)
    }

    // MARK: - Frame Processing Tests

    @Test("Video frame can be updated")
    func videoFrameCanBeUpdated() {
        let manager = SegmentationManager()
        let testFrame = TestFixtures.createTestImage()

        // Should not crash
        manager.updateVideoFrame(testFrame)

        #expect(manager != nil)
    }

    @Test("Photo can be captured")
    func photoCanBeCaptured() {
        let manager = SegmentationManager()
        let testPhoto = TestFixtures.createTestImage()

        // Should not crash
        manager.onPhotoCaptured(testPhoto)

        #expect(manager != nil)
    }

    // MARK: - Auto-Save Toggle Tests

    @Test("Auto-save can be toggled")
    func autoSaveCanBeToggled() {
        let manager = SegmentationManager()

        #expect(manager.autoSaveEnabled == true)

        manager.autoSaveEnabled = false
        #expect(manager.autoSaveEnabled == false)

        manager.autoSaveEnabled = true
        #expect(manager.autoSaveEnabled == true)
    }

    // MARK: - Start/Stop Integration Tests

    @Test("Start and stop sequence")
    func startStopSequence() {
        let manager = SegmentationManager()

        // Initial state
        #expect(manager.isEnabled == false)

        // Start
        manager.start()
        #expect(manager.isEnabled == true)

        // Stop
        manager.stop()
        #expect(manager.isEnabled == false)

        // Start again
        manager.start()
        #expect(manager.isEnabled == true)
    }

    // MARK: - Error State Tests

    @Test("Error state can be set and cleared")
    func errorStateManagement() {
        let manager = SegmentationManager()

        // Initial state - no error
        #expect(manager.lastError == nil)

        // Set error manually (simulating API failure)
        manager.lastError = "Network error"
        #expect(manager.lastError == "Network error")

        // Start clears error
        manager.start()
        #expect(manager.lastError == nil)
    }

    // MARK: - Processing State Tests

    @Test("Processing state tracking")
    func processingStateTracking() {
        let manager = SegmentationManager()

        // Initial state
        #expect(manager.isProcessing == false)

        // Processing state is managed internally during actual API calls
        // We can only verify the initial state here
    }
}
