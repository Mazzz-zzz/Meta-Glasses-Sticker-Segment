# Meta Stickers

A SwiftUI iOS application that streams video from Meta AI glasses and performs real-time object segmentation using the SAM3 (Segment Anything Model 3) API.

## Overview

Meta Stickers connects to Meta Ray-Ban smart glasses via the MWDAT SDK, streams live video, and uses fal.ai's SAM3 API to segment objects in real-time. The segmentation mask is overlaid on the video feed, enabling augmented reality-style object highlighting.

## Features

### Video Streaming

- Live video streaming from Meta AI glasses
- Configurable resolution (Low, Medium, High)
- Configurable frame rate (15, 24, 30 FPS)
- Photo capture functionality
- Time-limited streaming sessions

### SAM3 Segmentation

- Real-time object segmentation using fal.ai SAM3 API
- Customizable segmentation prompt (e.g., "object", "person", "hand", "face")
- Two image source modes:
  - **Video Frame (Silent)**: Uses video stream frames - lower quality but no sound
  - **Photo Capture (Higher Quality)**: Captures photos from camera - better quality but makes shutter sound
- Configurable polling interval (0.5s - 5s+)
- Mask overlay on video feed
- Status indicators and error reporting

### User Interface

- Native SwiftUI with iOS 26 support
- Top tab navigation (Stream / Settings)
- Light mode enforced for Stream tab
- Settings tab with full configuration options

## Requirements

- iOS 26.0+
- Xcode 16+
- Meta AI glasses (Ray-Ban Meta)
- fal.ai API key

## Setup

### 1. Clone the repository

```bash
git clone <repository-url>
cd meta-stickers
```

### 2. Configure API Key

Copy the example secrets file and add your fal.ai API key:

```bash
cp Secrets.swift.example meta-stickers/Secrets.swift
```

Edit `meta-stickers/Secrets.swift`:

```swift
enum Secrets {
    static let falAPIKey = "your-fal-ai-api-key-here"
}
```

> **Note**: `Secrets.swift` is gitignored and will not be committed.

### 3. Build and Run

Open `meta-stickers.xcodeproj` in Xcode and run on a device or simulator.

## Project Structure

```
meta-stickers/
├── meta-stickers/
│   ├── Services/
│   │   ├── FalAIService.swift      # SAM3 API client
│   │   └── SegmentationManager.swift # Polling & state management
│   ├── ViewModels/
│   │   ├── StreamSessionViewModel.swift
│   │   └── WearablesViewModel.swift
│   ├── Views/
│   │   ├── TabContainerView.swift   # Main tab navigation
│   │   ├── StreamView.swift         # Live video stream
│   │   ├── NonStreamView.swift      # Start streaming screen
│   │   └── Components/
│   │       ├── CircleButton.swift
│   │       └── CustomButton.swift
│   ├── Utils/
│   │   └── Config.swift             # API key configuration
│   └── Secrets.swift                # API keys (gitignored)
├── Secrets.swift.example            # Template for secrets
└── README.md
```

## Implemented Features

- [X] Meta glasses connection and video streaming
- [X] Photo capture from glasses camera
- [X] SAM3 API integration via fal.ai
- [X] Real-time segmentation mask overlay
- [X] Customizable segmentation prompt
- [X] Two image source modes (video frame / photo capture)
- [X] Configurable polling interval
- [X] Configurable stream resolution (Low/Medium/High)
- [X] Configurable frame rate (15/24/30 FPS)
- [X] Native SwiftUI tab navigation
- [X] Settings tab with all configuration options
- [X] Light mode for Stream tab
- [X] Secure API key management (gitignored secrets file)
- [X] Time-limited streaming sessions
- [X] Device connection status and refresh
- [X] Error handling and display

## TODO / Next Steps

### High Priority

- [ ] Save segmented images to photo library
- [ ] Multiple object tracking with different prompts
- [ ] Bounding box visualization option
- [ ] Confidence score threshold filtering

### Medium Priority

- [ ] Video recording with segmentation overlay
- [ ] Export segmentation masks as separate images
- [ ] History of recent segmentations
- [ ] Preset prompts (quick select common objects)
- [ ] WebSocket real-time mode for lower latency

### Low Priority / Future Ideas

- [ ] On-device segmentation (Core ML) for offline use
- [ ] Multi-mask support (segment multiple objects)
- [ ] Custom mask colors and opacity
- [ ] Share segmented images directly
- [ ] AR object placement on segmented areas
- [ ] Integration with other AI models (depth estimation, etc.)

### Technical Improvements

- [ ] Unit tests for FalAIService
- [ ] UI tests for main flows
- [ ] Better error recovery and retry logic
- [ ] Caching for repeated segmentation requests
- [ ] Performance profiling and optimization
- [ ] Support for iPad layout

## API Reference

### SAM3 API (fal.ai)

The app uses the `fal-ai/sam-3/image` endpoint:

**Input:**

- `image_url`: Base64 data URI or URL
- `prompt`: Text description of object to segment
- `apply_mask`: Whether to apply mask on image
- `output_format`: png/jpeg/webp

**Output:**

- `image`: Primary segmented mask preview
- `masks`: Array of segmentation masks
- `scores`: Confidence scores per mask
- `boxes`: Bounding boxes per mask

## References

### Meta Wearables DAT SDK

- **GitHub**: [facebook/meta-wearables-dat-ios](https://github.com/facebook/meta-wearables-dat-ios)
- Official iOS SDK for connecting to and streaming from Meta Ray-Ban smart glasses
- Provides `StreamSession`, `WearablesInterface`, and camera access APIs

### SAM3 (Segment Anything Model 3)

- **fal.ai API**: [fal-ai/sam-3/image](https://fal.ai/models/fal-ai/sam-3/image)
- **Paper**: [Segment Anything Model 3](https://ai.meta.com/sam3/) by Meta AI Research
- Unified foundation model for promptable segmentation in images and videos
- Supports text prompts, point prompts, and box prompts

### Related Documentation

- [fal.ai Swift Client](https://github.com/fal-ai/fal-swift)
- [Meta Ray-Ban Smart Glasses](https://www.meta.com/smart-glasses/)

## Acknowledgments

- [fal.ai](https://fal.ai) for the SAM3 API hosting
- [Meta](https://github.com/facebook/meta-wearables-dat-ios) for the MWDAT SDK
- Segment Anything Model 3 by Meta AI Research
