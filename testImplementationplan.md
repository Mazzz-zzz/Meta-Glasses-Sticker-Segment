# Unit Testing Implementation Plan

## Overview
Implementation of comprehensive unit testing for Meta Stickers app to ensure code quality, prevent regressions, and facilitate safe refactoring.

**Target iOS Version:** iOS 17+ (project targets iOS 26.0)
**Testing Framework:** XCTest + Swift Testing (iOS 16+)
**Start Date:** 2025-12-16
**Status:** Planning

---

## Pre-Implementation Checklist

- [ ] Verify test target exists in Xcode project
- [ ] Configure test scheme settings
- [ ] Set up code coverage reporting
- [ ] Create test utilities and helpers folder

---

## Phase 1: Test Infrastructure Setup

### 1.1 Create Test Target Structure
- [ ] Create `meta-stickersTests` target (if not exists)
- [ ] Create folder structure:
  ```
  meta-stickersTests/
  ├── Models/
  │   ├── StickerTests.swift
  │   ├── StickerCollectionTests.swift
  │   └── AppSettingsTests.swift
  ├── Services/
  │   ├── StickerDataManagerTests.swift
  │   ├── FalAIServiceTests.swift
  │   └── SegmentationManagerTests.swift
  ├── ViewModels/
  │   └── StreamSessionViewModelTests.swift
  ├── Utilities/
  │   └── ImageProcessingTests.swift
  ├── Mocks/
  │   ├── MockModelContext.swift
  │   ├── MockFalAIService.swift
  │   ├── MockWearablesInterface.swift
  │   └── MockURLSession.swift
  └── Helpers/
      ├── TestHelpers.swift
      └── TestFixtures.swift
  ```

### 1.2 Configure SwiftData for Testing
- [ ] Create in-memory ModelContainer for tests
- [ ] Create helper to reset database between tests
- [ ] Implement test fixture factory for models

**Comments:**
```
[Date]: [Notes about implementation]
```

---

## Phase 2: Model Tests

### 2.1 Sticker Model Tests
File: `Models/StickerTests.swift`

Test cases:
- [ ] `test_init_setsDefaultValues` - Verify default property values
- [ ] `test_init_withAllParameters` - Verify custom initialization
- [ ] `test_thumbnailImage_generatesFromImageData` - Thumbnail generation
- [ ] `test_fullImage_returnsUIImageFromData` - Full image retrieval
- [ ] `test_thumbnailImage_returnsNilForInvalidData` - Error handling
- [ ] `test_isFavorite_defaultsFalse` - Favorite default state
- [ ] `test_tags_defaultsEmpty` - Tags default state

```swift
// Example test structure
import Testing
import SwiftData
@testable import meta_stickers

@Suite("Sticker Model Tests")
struct StickerTests {

    @Test("Default initialization sets expected values")
    func init_setsDefaultValues() {
        let sticker = Sticker(imageData: Data(), prompt: "test")

        #expect(sticker.isFavorite == false)
        #expect(sticker.tags.isEmpty)
        #expect(sticker.score == nil)
    }
}
```

### 2.2 StickerCollection Model Tests
File: `Models/StickerCollectionTests.swift`

Test cases:
- [ ] `test_init_setsNameAndDefaults` - Verify initialization
- [ ] `test_stickers_defaultsEmpty` - Empty stickers array
- [ ] `test_relationship_stickerAddedToCollection` - Relationship integrity

### 2.3 AppSettings Model Tests
File: `Models/AppSettingsTests.swift`

Test cases:
- [ ] `test_init_setsDefaultSettings` - Default values
- [ ] `test_pollingInterval_defaultValue` - Default polling interval
- [ ] `test_currentPrompt_defaultValue` - Default prompt
- [ ] `test_autoSaveStickers_defaultTrue` - Auto-save default

**Comments:**
```
[Date]: [Notes about implementation]
```

---

## Phase 3: Service Tests

### 3.1 StickerDataManager Tests
File: `Services/StickerDataManagerTests.swift`

Test cases:
- [ ] `test_saveSticker_insertsIntoContext` - Save operation
- [ ] `test_saveSticker_fromUIImage_convertsData` - Image conversion
- [ ] `test_saveSticker_fromUIImage_returnsNilForFailure` - Error case
- [ ] `test_deleteSticker_removesFromContext` - Delete operation
- [ ] `test_deleteStickers_removesMultiple` - Batch delete
- [ ] `test_toggleFavorite_togglesState` - Favorite toggle
- [ ] `test_addTag_appendsTag` - Tag addition
- [ ] `test_addTag_preventsDuplicates` - Duplicate prevention
- [ ] `test_removeTag_removesTag` - Tag removal
- [ ] `test_fetchRecentStickers_sortsByDate` - Fetch sorting
- [ ] `test_fetchRecentStickers_respectsLimit` - Fetch limit
- [ ] `test_fetchFavorites_filtersCorrectly` - Favorites filter
- [ ] `test_fetchByPrompt_matchesPrompt` - Prompt search
- [ ] `test_getOrCreateSettings_createsIfNotExists` - Settings creation
- [ ] `test_getOrCreateSettings_returnsSingleton` - Singleton pattern
- [ ] `test_createCollection_insertsCollection` - Collection creation
- [ ] `test_addStickerToCollection_setsRelationship` - Collection relationship

```swift
// Example test with in-memory SwiftData
@Suite("StickerDataManager Tests")
struct StickerDataManagerTests {

    var modelContainer: ModelContainer!
    var modelContext: ModelContext!
    var dataManager: StickerDataManager!

    init() async throws {
        let schema = Schema([Sticker.self, StickerCollection.self, AppSettings.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(for: schema, configurations: [config])
        modelContext = ModelContext(modelContainer)
        dataManager = await StickerDataManager(modelContext: modelContext)
    }

    @Test("saveSticker inserts sticker into context")
    func saveSticker_insertsIntoContext() async {
        let testData = UIImage(systemName: "star")!.pngData()!

        let sticker = await dataManager.saveSticker(
            imageData: testData,
            prompt: "test prompt"
        )

        #expect(sticker.prompt == "test prompt")
        // Verify in context
        let fetched = await dataManager.fetchRecentStickers(limit: 1)
        #expect(fetched.count == 1)
    }
}
```

### 3.2 FalAIService Tests
File: `Services/FalAIServiceTests.swift`

Test cases:
- [ ] `test_segmentImage_sendsCorrectRequest` - Request formatting
- [ ] `test_segmentImage_handlesQueueResponse` - Queue handling
- [ ] `test_segmentImage_parsesSuccessResponse` - Response parsing
- [ ] `test_segmentImage_handlesNetworkError` - Error handling
- [ ] `test_segmentImage_handlesInvalidResponse` - Invalid response
- [ ] `test_pollForResult_retriesOnPending` - Polling retry
- [ ] `test_pollForResult_returnsOnComplete` - Polling completion
- [ ] `test_pollForResult_failsAfterMaxRetries` - Max retry limit
- [ ] `test_cropToOpaqueContent_cropsTransparency` - Image cropping

```swift
// Mock URLSession for network tests
class MockURLSession: URLSessionProtocol {
    var mockData: Data?
    var mockResponse: URLResponse?
    var mockError: Error?

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        if let error = mockError { throw error }
        return (mockData ?? Data(), mockResponse ?? URLResponse())
    }
}
```

### 3.3 SegmentationManager Tests
File: `Services/SegmentationManagerTests.swift`

Test cases:
- [ ] `test_start_setsIsEnabledTrue` - Start state
- [ ] `test_stop_setsIsEnabledFalse` - Stop state
- [ ] `test_setPollingInterval_updatesInterval` - Interval setting
- [ ] `test_setPrompt_updatesPrompt` - Prompt setting
- [ ] `test_processImage_callsFalAIService` - Service integration
- [ ] `test_processImage_addsToHistory` - History tracking
- [ ] `test_processImage_autoSavesWhenEnabled` - Auto-save feature
- [ ] `test_stickerHistory_limitsSize` - History size limit
- [ ] `test_clearHistory_removesAllItems` - History clearing

**Comments:**
```
[Date]: [Notes about implementation]
```

---

## Phase 4: ViewModel Tests

### 4.1 StreamSessionViewModel Tests
File: `ViewModels/StreamSessionViewModelTests.swift`

Test cases:
- [ ] `test_init_setsDefaultState` - Initial state
- [ ] `test_startStreaming_setsIsStreamingTrue` - Start streaming
- [ ] `test_stopStreaming_setsIsStreamingFalse` - Stop streaming
- [ ] `test_applyStreamSettings_updatesQuality` - Quality setting
- [ ] `test_applyStreamSettings_updatesFPS` - FPS setting
- [ ] `test_handleFrame_processesVideoFrame` - Frame processing
- [ ] `test_showError_setsErrorMessage` - Error display
- [ ] `test_dismissError_clearsError` - Error dismissal

**Comments:**
```
[Date]: [Notes about implementation]
```

---

## Phase 5: Utility & Extension Tests

### 5.1 Image Processing Tests
File: `Utilities/ImageProcessingTests.swift`

Test cases:
- [ ] `test_cropToOpaqueContent_removesTransparentEdges` - Cropping
- [ ] `test_cropToOpaqueContent_handlesFullyOpaque` - No-op case
- [ ] `test_cropToOpaqueContent_handlesFullyTransparent` - Edge case
- [ ] `test_thumbnailGeneration_resizesCorrectly` - Thumbnail size

**Comments:**
```
[Date]: [Notes about implementation]
```

---

## Phase 6: Test Helpers & Mocks

### 6.1 Test Fixtures
File: `Helpers/TestFixtures.swift`

```swift
import Foundation
import UIKit
@testable import meta_stickers

enum TestFixtures {

    static func createTestImageData(size: CGSize = CGSize(width: 100, height: 100)) -> Data {
        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
        UIColor.red.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))
        let image = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return image.pngData()!
    }

    static func createTestSticker(
        prompt: String = "test",
        isFavorite: Bool = false,
        tags: [String] = []
    ) -> Sticker {
        let sticker = Sticker(
            imageData: createTestImageData(),
            prompt: prompt
        )
        sticker.isFavorite = isFavorite
        sticker.tags = tags
        return sticker
    }

    static func createTestCollection(name: String = "Test Collection") -> StickerCollection {
        StickerCollection(name: name)
    }
}
```

### 6.2 Mock Services
File: `Mocks/MockFalAIService.swift`

```swift
import Foundation
import UIKit
@testable import meta_stickers

class MockFalAIService {
    var segmentImageCalled = false
    var lastImageData: Data?
    var lastPrompt: String?
    var mockResult: SegmentationResult?
    var mockError: Error?

    func segmentImage(imageData: Data, prompt: String) async throws -> SegmentationResult {
        segmentImageCalled = true
        lastImageData = imageData
        lastPrompt = prompt

        if let error = mockError {
            throw error
        }

        return mockResult ?? SegmentationResult(
            maskedImage: UIImage(systemName: "star")!,
            score: 0.95,
            boundingBox: nil,
            timestamp: Date()
        )
    }
}
```

### 6.3 SwiftData Test Helpers
File: `Helpers/TestHelpers.swift`

```swift
import SwiftData
@testable import meta_stickers

@MainActor
enum TestHelpers {

    static func createInMemoryModelContainer() throws -> ModelContainer {
        let schema = Schema([
            Sticker.self,
            StickerCollection.self,
            AppSettings.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    static func createTestDataManager() throws -> StickerDataManager {
        let container = try createInMemoryModelContainer()
        let context = ModelContext(container)
        return StickerDataManager(modelContext: context)
    }
}
```

**Comments:**
```
[Date]: [Notes about implementation]
```

---

## Phase 7: Integration Tests

### 7.1 Data Flow Integration Tests
File: `Integration/DataFlowTests.swift`

Test cases:
- [ ] `test_stickerCreationToLibraryDisplay` - End-to-end sticker flow
- [ ] `test_settingsPersistence` - Settings save/load cycle
- [ ] `test_collectionManagement` - Collection CRUD operations

### 7.2 Segmentation Pipeline Tests
File: `Integration/SegmentationPipelineTests.swift`

Test cases:
- [ ] `test_imageToStickerPipeline` - Full segmentation flow (with mocked API)
- [ ] `test_autoSaveIntegration` - Auto-save with data manager

**Comments:**
```
[Date]: [Notes about implementation]
```

---

## Phase 8: CI/CD Integration

### 8.1 Test Configuration
- [ ] Configure test scheme for CI
- [ ] Set up code coverage thresholds (target: 70%)
- [ ] Configure parallel test execution
- [ ] Set up test result reporting

### 8.2 GitHub Actions (Optional)
```yaml
# .github/workflows/tests.yml
name: Tests

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v4
      - name: Select Xcode
        run: sudo xcode-select -s /Applications/Xcode_15.2.app
      - name: Run Tests
        run: |
          xcodebuild test \
            -project meta-stickers.xcodeproj \
            -scheme meta-stickers \
            -destination 'platform=iOS Simulator,name=iPhone 15' \
            -enableCodeCoverage YES
```

**Comments:**
```
[Date]: [Notes about implementation]
```

---

## Testing Best Practices

### Naming Convention
```
test_<methodName>_<scenario>_<expectedBehavior>
```
Examples:
- `test_saveSticker_withValidData_insertsSuccessfully`
- `test_fetchFavorites_whenEmpty_returnsEmptyArray`

### Test Organization (AAA Pattern)
```swift
@Test("Description of what is being tested")
func testName() {
    // Arrange - Set up test data and conditions
    let input = "test"

    // Act - Execute the code being tested
    let result = functionUnderTest(input)

    // Assert - Verify the expected outcome
    #expect(result == expectedValue)
}
```

### Async Testing
```swift
@Test("Async operation completes successfully")
func asyncOperation() async throws {
    let service = MockService()

    let result = try await service.performAsyncOperation()

    #expect(result != nil)
}
```

### MainActor Testing
```swift
@Test("MainActor isolated code")
@MainActor
func mainActorTest() {
    let manager = StickerDataManager(modelContext: testContext)
    // Test MainActor-isolated code
}
```

---

## Coverage Goals

| Component | Target Coverage |
|-----------|----------------|
| Models | 90% |
| Services | 80% |
| ViewModels | 70% |
| Utilities | 85% |
| Overall | 75% |

---

## Completion Tracking

| Phase | Status | Completion Date |
|-------|--------|-----------------|
| Phase 1: Infrastructure Setup | Pending | - |
| Phase 2: Model Tests | Pending | - |
| Phase 3: Service Tests | Pending | - |
| Phase 4: ViewModel Tests | Pending | - |
| Phase 5: Utility Tests | Pending | - |
| Phase 6: Helpers & Mocks | Pending | - |
| Phase 7: Integration Tests | Pending | - |
| Phase 8: CI/CD Integration | Pending | - |

---

## Dependencies

- XCTest (built-in)
- Swift Testing framework (iOS 16+)
- SwiftData for in-memory testing

---

## Notes

- Use `@MainActor` for tests involving SwiftData and UI-related code
- Always use in-memory ModelContainer for tests to ensure isolation
- Mock external dependencies (network, file system) for unit tests
- Keep tests fast - aim for <100ms per unit test
- Integration tests can be slower but should still complete in <5s each
