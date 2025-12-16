//
//  meta_stickersTests.swift
//  meta-stickersTests
//
//  Created by Almaz Khalilov on 13/12/2025.
//

import Testing
@testable import meta_stickers

/// Root test suite for meta-stickers app
///
/// Test organization:
/// - Models/: Tests for SwiftData models (Sticker, StickerCollection, AppSettings)
/// - Services/: Tests for business logic services (StickerDataManager, FalAIService, SegmentationManager)
/// - ViewModels/: Tests for view models (StreamSessionViewModel)
/// - Utilities/: Tests for utility functions (Image processing)
/// - Integration/: End-to-end flow tests
/// - Helpers/: Test utilities and fixtures
/// - Mocks/: Mock implementations for testing

@Suite("Meta Stickers Tests")
struct MetaStickersTests {

    @Test("Test infrastructure is working")
    func testInfrastructure_isWorking() {
        #expect(true)
    }
}
