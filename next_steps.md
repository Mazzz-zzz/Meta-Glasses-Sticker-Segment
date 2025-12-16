# Next Steps: Phone Camera Streaming Support

## Overview

Add phone camera as an alternative video source alongside Meta glasses streaming.

**Difficulty:** Moderate
**Estimated Effort:** 3-5 days

---

## Current Architecture

```
Meta Glasses Camera
    ↓
StreamSession (Meta SDK)
    ↓
StreamSessionViewModel.currentVideoFrame
    ↓
├── StreamView (display)
└── SegmentationManager (processing) → FAL SAM-3 API
```

## Target Architecture

```
┌─────────────────┐     ┌─────────────────┐
│  Meta Glasses   │     │  Phone Camera   │
│    Camera       │     │  (AVFoundation) │
└────────┬────────┘     └────────┬────────┘
         │                       │
         └───────────┬───────────┘
                     ↓
          CameraStreamSource (Protocol)
                     ↓
          StreamSessionViewModel.currentVideoFrame
                     ↓
         ├── StreamView (display)
         └── SegmentationManager (processing)
```

---

## Implementation Tasks

### 1. Create Camera Abstraction Protocol

**File:** `meta-stickers/Protocols/CameraStreamSource.swift`

```swift
import UIKit
import Combine

enum CameraSourceType: String, CaseIterable {
    case metaGlasses = "Meta Glasses"
    case phoneCamera = "Phone Camera"
}

enum CameraStreamState {
    case stopped
    case starting
    case streaming
    case stopping
    case error(String)
}

protocol CameraStreamSource: AnyObject {
    var videoFramePublisher: AnyPublisher<UIImage, Never> { get }
    var statePublisher: AnyPublisher<CameraStreamState, Never> { get }
    var errorPublisher: AnyPublisher<Error, Never> { get }

    func start() async
    func stop() async
    func capturePhoto() async -> UIImage?

    var isStreaming: Bool { get }
    var sourceType: CameraSourceType { get }
}
```

### 2. Wrap Meta Glasses in Protocol

**File:** `meta-stickers/Services/MetaGlassesCameraSource.swift`

- Wrap existing `StreamSession` from Meta SDK
- Conform to `CameraStreamSource` protocol
- Handle Meta SDK permission flow
- Convert `VideoFrame` to `UIImage` in publisher

### 3. Implement Phone Camera Source

**File:** `meta-stickers/Services/PhoneCameraCameraSource.swift`

```swift
import AVFoundation
import UIKit
import Combine

class PhoneCameraCameraSource: NSObject, CameraStreamSource {
    private var captureSession: AVCaptureSession?
    private var videoOutput: AVCaptureVideoDataOutput?
    private let sessionQueue = DispatchQueue(label: "camera.session")

    private let videoFrameSubject = PassthroughSubject<UIImage, Never>()
    private let stateSubject = CurrentValueSubject<CameraStreamState, Never>(.stopped)
    private let errorSubject = PassthroughSubject<Error, Never>()

    var videoFramePublisher: AnyPublisher<UIImage, Never> { videoFrameSubject.eraseToAnyPublisher() }
    var statePublisher: AnyPublisher<CameraStreamState, Never> { stateSubject.eraseToAnyPublisher() }
    var errorPublisher: AnyPublisher<Error, Never> { errorSubject.eraseToAnyPublisher() }

    // Resolution & FPS configuration
    var resolution: StreamQuality = .high
    var frameRate: StreamFPS = .fps30

    func start() async {
        // 1. Request camera permission
        // 2. Configure AVCaptureSession
        // 3. Add video input (back camera)
        // 4. Add video output with delegate
        // 5. Start running
    }

    func stop() async {
        captureSession?.stopRunning()
        stateSubject.send(.stopped)
    }
}

extension PhoneCameraCameraSource: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput,
                      didOutput sampleBuffer: CMSampleBuffer,
                      from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return }
        let uiImage = UIImage(cgImage: cgImage)
        videoFrameSubject.send(uiImage)
    }
}
```

### 4. Update StreamSessionViewModel

**File:** `meta-stickers/ViewModels/StreamSessionViewModel.swift`

Changes needed:
- Replace `StreamSession` with `CameraStreamSource` protocol
- Add `@Published var cameraSourceType: CameraSourceType`
- Add method to switch between sources
- Update permission handling for both source types

```swift
@Published var cameraSourceType: CameraSourceType = .metaGlasses
private var cameraSource: CameraStreamSource?

func selectCameraSource(_ type: CameraSourceType) async {
    await cameraSource?.stop()

    switch type {
    case .metaGlasses:
        cameraSource = MetaGlassesCameraSource(wearables: wearables, config: currentConfig)
    case .phoneCamera:
        cameraSource = PhoneCameraCameraSource(resolution: streamQuality, frameRate: streamFPS)
    }

    cameraSourceType = type
    setupSourceListeners()
}
```

### 5. Add Source Selection UI

**File:** `meta-stickers/Views/TabContainerView.swift` (Settings section)

Add picker in Settings tab:
```swift
Section(header: Text("Camera Source")) {
    Picker("Source", selection: $viewModel.cameraSourceType) {
        ForEach(CameraSourceType.allCases, id: \.self) { source in
            Text(source.rawValue).tag(source)
        }
    }

    if viewModel.cameraSourceType == .metaGlasses && wearables.devices.isEmpty {
        Text("No glasses connected")
            .font(.caption)
            .foregroundColor(.orange)
    }
}
```

### 6. Update AppSettings

**File:** `meta-stickers/Models/AppSettings.swift`

Add:
```swift
/// Camera source: "metaGlasses" or "phoneCamera"
var cameraSource: String = "metaGlasses"
```

### 7. Permission Handling

Phone camera requires different permission flow:

```swift
func requestPhoneCameraPermission() async -> Bool {
    let status = AVCaptureDevice.authorizationStatus(for: .video)
    switch status {
    case .authorized:
        return true
    case .notDetermined:
        return await AVCaptureDevice.requestAccess(for: .video)
    case .denied, .restricted:
        return false
    @unknown default:
        return false
    }
}
```

---

## Files to Create

| File | Purpose |
|------|---------|
| `Protocols/CameraStreamSource.swift` | Abstract protocol for camera sources |
| `Services/MetaGlassesCameraSource.swift` | Meta SDK wrapper |
| `Services/PhoneCameraCameraSource.swift` | AVFoundation implementation |

## Files to Modify

| File | Changes |
|------|---------|
| `ViewModels/StreamSessionViewModel.swift` | Use protocol, add source switching |
| `Models/AppSettings.swift` | Add `cameraSource` setting |
| `Views/TabContainerView.swift` | Add source picker in Settings |
| `Info.plist` | Already has camera permission (verify wording) |

---

## Testing Checklist

- [ ] Phone camera permission request flow
- [ ] Permission denied handling
- [ ] Frame delivery at correct FPS
- [ ] Resolution matches settings
- [ ] Segmentation works with phone frames
- [ ] Switching between sources mid-session
- [ ] Auto-fallback when glasses disconnected
- [ ] Battery/thermal performance
- [ ] Portrait/landscape orientation
- [ ] Background/foreground transitions

---

## Risk Factors

1. **Thermal throttling** - Sustained camera + network may throttle CPU
2. **Battery drain** - Continuous capture is power-intensive
3. **Frame quality differences** - Phone cameras produce different quality than glasses
4. **Orientation handling** - Phone has portrait/landscape; glasses don't
5. **Device variations** - Phone cameras vary by model

---

## Optional Enhancements

- Auto-detect and suggest phone camera when no glasses connected
- Picture-in-picture mode showing both sources
- Front/back camera toggle for phone
- Torch/flash support for phone camera
