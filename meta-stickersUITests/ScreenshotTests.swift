//
//  ScreenshotTests.swift
//  meta-stickersUITests
//
//  Automated screenshot capture for App Store submissions
//

import XCTest

final class ScreenshotTests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()

        // Set launch arguments for screenshot mode
        app.launchArguments += ["-UITestMode", "true"]
        app.launchArguments += ["-AppleLanguages", "(en)"]
        app.launchArguments += ["-AppleLocale", "en_US"]

        setupSnapshot(app)
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Screenshot Capture

    @MainActor
    func testCaptureAllScreenshots() throws {
        // Wait for the app to fully load
        sleep(2)

        // Check if on home screen or main app
        let connectButton = app.buttons["connectGlassesButton"]
        let tabPicker = app.segmentedControls["tabPicker"]

        if connectButton.exists {
            // Screenshot 1: Home/Connect Screen
            takeScreenshot(named: "01_Home_Connect")
        }

        // Try to find the tab picker (indicates we're in the main app)
        if tabPicker.waitForExistence(timeout: 5) {
            captureTabScreenshots()
        }
    }

    @MainActor
    func testCaptureLibraryScreenshot() throws {
        sleep(2)

        let tabPicker = app.segmentedControls["tabPicker"]
        guard tabPicker.waitForExistence(timeout: 5) else {
            XCTFail("Tab picker not found - app may be on home screen")
            return
        }

        // Navigate to Library tab
        tapTab(named: "Library", in: tabPicker)
        sleep(1)
        takeScreenshot(named: "04_Library")
    }

    @MainActor
    func testCaptureStyleScreenshot() throws {
        sleep(2)

        let tabPicker = app.segmentedControls["tabPicker"]
        guard tabPicker.waitForExistence(timeout: 5) else {
            return
        }

        // Navigate to Style tab
        tapTab(named: "Style", in: tabPicker)
        sleep(1)
        takeScreenshot(named: "03_Style")
    }

    @MainActor
    func testCaptureCutoutScreenshot() throws {
        sleep(2)

        let tabPicker = app.segmentedControls["tabPicker"]
        guard tabPicker.waitForExistence(timeout: 5) else {
            return
        }

        // Navigate to Cutout tab
        tapTab(named: "Cutout", in: tabPicker)
        sleep(1)
        takeScreenshot(named: "02_Cutout")
    }

    @MainActor
    func testCaptureSettingsScreenshot() throws {
        sleep(2)

        let tabPicker = app.segmentedControls["tabPicker"]
        guard tabPicker.waitForExistence(timeout: 5) else {
            return
        }

        // Navigate to Settings tab
        tapTab(named: "Settings", in: tabPicker)
        sleep(1)
        takeScreenshot(named: "05_Settings")
    }

    // MARK: - Helper Methods

    @MainActor
    private func captureTabScreenshots() {
        let tabPicker = app.segmentedControls["tabPicker"]

        // Stream tab (first/default)
        takeScreenshot(named: "02_Stream")

        // Cutout tab
        tapTab(named: "Cutout", in: tabPicker)
        sleep(1)
        takeScreenshot(named: "03_Cutout")

        // Style tab
        tapTab(named: "Style", in: tabPicker)
        sleep(1)
        takeScreenshot(named: "04_Style")

        // Library tab
        tapTab(named: "Library", in: tabPicker)
        sleep(1)
        takeScreenshot(named: "05_Library")

        // Settings tab
        tapTab(named: "Settings", in: tabPicker)
        sleep(1)
        takeScreenshot(named: "06_Settings")
    }

    private func tapTab(named name: String, in picker: XCUIElement) {
        // Try by accessibility identifier first
        let buttonById = picker.buttons["tab_\(name)"]
        if buttonById.exists {
            buttonById.tap()
            return
        }

        // Try by button text
        let buttonByText = picker.buttons[name]
        if buttonByText.exists {
            buttonByText.tap()
            return
        }

        // For Settings (gear icon), try by index
        if name == "Settings" {
            let lastButton = picker.buttons.element(boundBy: picker.buttons.count - 1)
            if lastButton.exists {
                lastButton.tap()
            }
        }
    }

    private func takeScreenshot(named name: String) {
        // Use Fastlane snapshot if available
        snapshot(name)

        // Also save using XCTest attachment for redundancy
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

// MARK: - Fastlane Snapshot Helpers

/// Placeholder function - Fastlane will replace this
func setupSnapshot(_ app: XCUIApplication, waitForAnimations: Bool = true) {
    // Fastlane injects real implementation
}

/// Placeholder function - Fastlane will replace this
func snapshot(_ name: String, waitForLoadingIndicator: Bool = true) {
    // Fastlane injects real implementation
}
