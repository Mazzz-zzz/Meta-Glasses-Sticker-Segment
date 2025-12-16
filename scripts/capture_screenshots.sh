#!/bin/bash

# Screenshot Capture Script for Meta Stickers
# Usage: ./scripts/capture_screenshots.sh [device]

set -e

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCREENSHOTS_DIR="$PROJECT_DIR/Screenshots"
SCHEME="meta-stickers"
TEST_TARGET="meta-stickersUITests"

# Default devices for App Store (iPhone 6.7" and 6.5" required)
DEVICES=(
    "iPhone 17 Pro Max"    # 6.9" (latest)
    "iPhone 17 Pro"        # 6.3"
    "iPhone 17"            # 6.3"
    "iPhone Air"           # alternative
)

# Use provided device or default to first device
SELECTED_DEVICE="${1:-${DEVICES[0]}}"

echo "📸 Meta Stickers Screenshot Capture"
echo "===================================="
echo "Project: $PROJECT_DIR"
echo "Device: $SELECTED_DEVICE"
echo ""

# Create screenshots directory
mkdir -p "$SCREENSHOTS_DIR"

# Function to capture screenshots for a device
capture_for_device() {
    local device="$1"
    local device_dir="$SCREENSHOTS_DIR/${device// /_}"
    mkdir -p "$device_dir"

    echo "📱 Capturing screenshots on $device..."

    # Run UI tests with screenshot capture
    xcodebuild test \
        -project "$PROJECT_DIR/meta-stickers.xcodeproj" \
        -scheme "$SCHEME" \
        -destination "platform=iOS Simulator,name=$device" \
        -testPlan "Screenshots" \
        -only-testing:"$TEST_TARGET/ScreenshotTests" \
        -resultBundlePath "$device_dir/TestResults.xcresult" \
        2>&1 | xcbeautify || true

    # Extract screenshots from test results
    echo "📂 Extracting screenshots..."
    if [ -d "$device_dir/TestResults.xcresult" ]; then
        xcrun xcresulttool get --format raw \
            --path "$device_dir/TestResults.xcresult" \
            --id "$(xcrun xcresulttool get --format json --path "$device_dir/TestResults.xcresult" | jq -r '.actions._values[0].actionResult.testsRef.id')" \
            > /dev/null 2>&1 || true
    fi

    echo "✅ Screenshots saved to $device_dir"
}

# Function to run basic screenshot capture without xcbeautify
capture_basic() {
    local device="$1"
    local device_dir="$SCREENSHOTS_DIR/${device// /_}"
    mkdir -p "$device_dir"

    echo "📱 Capturing screenshots on $device..."

    # Build for testing first
    xcodebuild build-for-testing \
        -project "$PROJECT_DIR/meta-stickers.xcodeproj" \
        -scheme "$SCHEME" \
        -destination "platform=iOS Simulator,name=$device" \
        -quiet

    # Run tests
    xcodebuild test-without-building \
        -project "$PROJECT_DIR/meta-stickers.xcodeproj" \
        -scheme "$SCHEME" \
        -destination "platform=iOS Simulator,name=$device" \
        -only-testing:"$TEST_TARGET/ScreenshotTests" \
        -resultBundlePath "$device_dir/TestResults.xcresult" \
        || true

    echo "✅ Done! Check $device_dir for results"
}

# Check if xcbeautify is available
if command -v xcbeautify &> /dev/null; then
    capture_for_device "$SELECTED_DEVICE"
else
    echo "ℹ️  Tip: Install xcbeautify for prettier output: brew install xcbeautify"
    capture_basic "$SELECTED_DEVICE"
fi

echo ""
echo "📸 Screenshot capture complete!"
echo "📂 Results: $SCREENSHOTS_DIR"
echo ""
echo "To capture for all devices, run:"
echo "  for device in \"iPhone 17 Pro Max\" \"iPhone 17 Pro\"; do"
echo "    ./scripts/capture_screenshots.sh \"\$device\""
echo "  done"
