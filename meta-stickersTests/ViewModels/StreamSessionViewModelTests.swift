//
//  StreamSessionViewModelTests.swift
//  meta-stickersTests
//

import Testing
import UIKit
@testable import meta_stickers

// Note: StreamSessionViewModel has dependencies on MWDATCamera and MWDATCore
// which require device connectivity. These tests focus on testable aspects.

@Suite("StreamSessionViewModel Tests")
struct StreamSessionViewModelTests {

    // MARK: - StreamingStatus Enum Tests

    @Test("StreamingStatus has expected cases")
    func streamingStatus_hasExpectedCases() {
        let streaming = StreamingStatus.streaming
        let waiting = StreamingStatus.waiting
        let stopped = StreamingStatus.stopped

        #expect(streaming != waiting)
        #expect(waiting != stopped)
        #expect(streaming != stopped)
    }

    // MARK: - StreamQuality Enum Tests

    @Test("StreamQuality has expected cases")
    func streamQuality_hasExpectedCases() {
        let allCases = StreamQuality.allCases

        #expect(allCases.count == 3)
        #expect(allCases.contains(.low))
        #expect(allCases.contains(.medium))
        #expect(allCases.contains(.high))
    }

    @Test("StreamQuality raw values are correct")
    func streamQuality_rawValues() {
        #expect(StreamQuality.low.rawValue == "Low")
        #expect(StreamQuality.medium.rawValue == "Medium")
        #expect(StreamQuality.high.rawValue == "High")
    }

    @Test("StreamQuality resolution property exists")
    func streamQuality_resolutionProperty() {
        // Just verify the property is accessible (actual resolution depends on MWDATCamera)
        let _ = StreamQuality.low.resolution
        let _ = StreamQuality.medium.resolution
        let _ = StreamQuality.high.resolution
    }

    // MARK: - StreamFPS Enum Tests

    @Test("StreamFPS has expected cases")
    func streamFPS_hasExpectedCases() {
        let allCases = StreamFPS.allCases

        #expect(allCases.count == 3)
        #expect(allCases.contains(.fps15))
        #expect(allCases.contains(.fps24))
        #expect(allCases.contains(.fps30))
    }

    @Test("StreamFPS raw values are correct")
    func streamFPS_rawValues() {
        #expect(StreamFPS.fps15.rawValue == 15)
        #expect(StreamFPS.fps24.rawValue == 24)
        #expect(StreamFPS.fps30.rawValue == 30)
    }

    @Test("StreamFPS displayName is formatted correctly")
    func streamFPS_displayName() {
        #expect(StreamFPS.fps15.displayName == "15 FPS")
        #expect(StreamFPS.fps24.displayName == "24 FPS")
        #expect(StreamFPS.fps30.displayName == "30 FPS")
    }
}

// MARK: - StreamTimeLimit Tests (if accessible)
// Note: StreamTimeLimit is used by StreamSessionViewModel but may not be directly testable
// without the full ViewModel context
