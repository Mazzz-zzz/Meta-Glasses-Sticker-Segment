//
//  StreamSessionViewModel.swift
//  meta-stickers
//

import Combine
import MWDATCamera
import MWDATCore
import SwiftUI

enum StreamingStatus {
    case streaming
    case waiting
    case stopped
}

enum StreamQuality: String, CaseIterable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"

    var resolution: StreamingResolution {
        switch self {
        case .low: return .low
        case .medium: return .medium
        case .high: return .high
        }
    }
}

enum StreamFPS: UInt, CaseIterable {
    case fps15 = 15
    case fps24 = 24
    case fps30 = 30

    var displayName: String {
        "\(rawValue) FPS"
    }
}

@MainActor
class StreamSessionViewModel: ObservableObject {
    @Published var currentVideoFrame: UIImage?
    @Published var hasReceivedFirstFrame: Bool = false
    @Published var streamingStatus: StreamingStatus = .stopped
    @Published var showError: Bool = false
    @Published var errorMessage: String = ""

    var isStreaming: Bool {
        streamingStatus != .stopped
    }

    @Published var activeTimeLimit: StreamTimeLimit = .noLimit
    @Published var remainingTime: TimeInterval = 0

    @Published var capturedPhoto: UIImage?
    @Published var showPhotoPreview: Bool = false

    // Stream settings
    @Published var streamQuality: StreamQuality = .low
    @Published var streamFPS: StreamFPS = .fps24

    // Segmentation
    let segmentationManager: SegmentationManager

    private var timerTask: Task<Void, Never>?
    private var streamSession: StreamSession
    private var stateListenerToken: AnyListenerToken?
    private var videoFrameListenerToken: AnyListenerToken?
    private var errorListenerToken: AnyListenerToken?
    private var photoDataListenerToken: AnyListenerToken?
    private let wearables: WearablesInterface
    private let deviceSelector: AutoDeviceSelector

    private var isSegmentationCapture = false

    init(wearables: WearablesInterface, falAPIKey: String? = nil) {
        self.wearables = wearables
        self.segmentationManager = SegmentationManager(apiKey: falAPIKey)
        self.deviceSelector = AutoDeviceSelector(wearables: wearables)

        // Use default values for initial config
        let config = StreamSessionConfig(
            videoCodec: VideoCodec.raw,
            resolution: StreamQuality.low.resolution,
            frameRate: StreamFPS.fps24.rawValue)
        streamSession = StreamSession(streamSessionConfig: config, deviceSelector: deviceSelector)

        setupListeners()

        // Set up segmentation to request photo captures
        segmentationManager.setPhotoCaptureCallback { [weak self] in
            Task { @MainActor [weak self] in
                self?.capturePhotoForSegmentation()
            }
        }
    }

    private func capturePhotoForSegmentation() {
        isSegmentationCapture = true
        streamSession.capturePhoto(format: .jpeg)
    }

    func handleStartStreaming() async {
        // Check if any devices are available
        guard !wearables.devices.isEmpty else {
            showError("No glasses connected. Please make sure your Meta AI glasses are paired and connected via Bluetooth.")
            return
        }

        let permission = Permission.camera
        do {
            let status = try await wearables.checkPermissionStatus(permission)
            if status == .granted {
                startSession()
                return
            }
            let requestStatus = try await wearables.requestPermission(permission)
            if requestStatus == .granted {
                startSession()
                return
            }
            showError("Camera permission denied. Please grant camera access in your glasses settings.")
        } catch {
            // Provide helpful error message based on error description
            let errorDesc = String(describing: error)
            if errorDesc.contains("not registered") || errorDesc.contains("NotRegistered") {
                showError("Not registered. Please connect your glasses first.")
            } else if errorDesc.contains("not connected") || errorDesc.contains("NotConnected") {
                showError("Glasses not connected. Please ensure your Meta AI glasses are connected via Bluetooth.")
            } else if errorDesc.contains("denied") || errorDesc.contains("Denied") {
                showError("Camera permission denied. Please grant camera access in your glasses settings.")
            } else {
                showError("Unable to start streaming. Please ensure your glasses are connected and try again.\n\nError: \(error.localizedDescription)")
            }
        }
    }

    func startSession() {
        activeTimeLimit = .noLimit
        remainingTime = 0
        stopTimer()

        // Recreate stream session with current settings
        recreateStreamSession()

        Task {
            await streamSession.start()
        }
    }

    func applyStreamSettings(quality: StreamQuality, fps: StreamFPS) {
        let wasStreaming = isStreaming
        streamQuality = quality
        streamFPS = fps

        if wasStreaming {
            // Restart stream with new settings
            Task {
                await streamSession.stop()
                recreateStreamSession()
                await streamSession.start()
            }
        }
    }

    private func recreateStreamSession() {
        // Clear existing listeners
        stateListenerToken = nil
        videoFrameListenerToken = nil
        errorListenerToken = nil
        photoDataListenerToken = nil

        let config = StreamSessionConfig(
            videoCodec: VideoCodec.raw,
            resolution: streamQuality.resolution,
            frameRate: streamFPS.rawValue)
        streamSession = StreamSession(streamSessionConfig: config, deviceSelector: deviceSelector)

        // Re-setup listeners
        setupListeners()
    }

    private func setupListeners() {
        stateListenerToken = streamSession.statePublisher.listen { [weak self] state in
            Task { @MainActor [weak self] in
                self?.updateStatusFromState(state)
            }
        }

        videoFrameListenerToken = streamSession.videoFramePublisher.listen { [weak self] videoFrame in
            Task { @MainActor [weak self] in
                guard let self else { return }

                if let image = videoFrame.makeUIImage() {
                    self.currentVideoFrame = image
                    if !self.hasReceivedFirstFrame {
                        self.hasReceivedFirstFrame = true
                    }
                    self.segmentationManager.updateVideoFrame(image)
                }
            }
        }

        errorListenerToken = streamSession.errorPublisher.listen { [weak self] error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let newErrorMessage = self.formatStreamingError(error)
                if newErrorMessage != self.errorMessage {
                    self.showError(newErrorMessage)
                }
            }
        }

        photoDataListenerToken = streamSession.photoDataPublisher.listen { [weak self] photoData in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let uiImage = UIImage(data: photoData.data) {
                    if self.isSegmentationCapture {
                        self.segmentationManager.onPhotoCaptured(uiImage)
                        self.isSegmentationCapture = false
                    } else {
                        self.capturedPhoto = uiImage
                        self.showPhotoPreview = true
                    }
                }
            }
        }

        updateStatusFromState(streamSession.state)
    }

    private func showError(_ message: String) {
        errorMessage = message
        showError = true
    }

    func stopSession() {
        stopTimer()
        segmentationManager.stop()
        Task {
            await streamSession.stop()
        }
    }

    func dismissError() {
        showError = false
        errorMessage = ""
    }

    func setTimeLimit(_ limit: StreamTimeLimit) {
        activeTimeLimit = limit
        remainingTime = limit.durationInSeconds ?? 0

        if limit.isTimeLimited {
            startTimer()
        } else {
            stopTimer()
        }
    }

    func cycleTimeLimit() {
        setTimeLimit(activeTimeLimit.next)
    }

    func capturePhoto() {
        streamSession.capturePhoto(format: .jpeg)
    }

    func dismissPhotoPreview() {
        showPhotoPreview = false
        capturedPhoto = nil
    }

    private func startTimer() {
        stopTimer()
        timerTask = Task { @MainActor [weak self] in
            while let self, remainingTime > 0 {
                try? await Task.sleep(nanoseconds: NSEC_PER_SEC)
                guard !Task.isCancelled else { break }
                remainingTime -= 1
            }
            if let self, !Task.isCancelled {
                stopSession()
            }
        }
    }

    private func stopTimer() {
        timerTask?.cancel()
        timerTask = nil
    }

    private func updateStatusFromState(_ state: StreamSessionState) {
        switch state {
        case .stopped:
            currentVideoFrame = nil
            streamingStatus = .stopped
        case .waitingForDevice, .starting, .stopping, .paused:
            streamingStatus = .waiting
        case .streaming:
            streamingStatus = .streaming
        @unknown default:
            break
        }
    }

    private func formatStreamingError(_ error: StreamSessionError) -> String {
        switch error {
        case .internalError:
            return "An internal error occurred. Please try again."
        case .deviceNotFound:
            return "Device not found. Please ensure your device is connected."
        case .deviceNotConnected:
            return "Device not connected. Please check your connection and try again."
        case .timeout:
            return "The operation timed out. Please try again."
        case .videoStreamingError:
            return "Video streaming failed. Please try again."
        case .audioStreamingError:
            return "Audio streaming failed. Please try again."
        case .permissionDenied:
            return "Camera permission denied. Please grant permission in Settings."
        @unknown default:
            return "An unknown streaming error occurred."
        }
    }
}
