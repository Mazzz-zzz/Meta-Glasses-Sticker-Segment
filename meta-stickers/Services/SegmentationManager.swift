//
//  SegmentationManager.swift
//  meta-stickers
//

import Foundation
import UIKit
import Combine

struct SegmentationResult {
    let maskImage: UIImage?
    let maskURL: String?
    let score: Float?
    let boundingBox: [Float]?
    let timestamp: Date
}

enum SegmentationSource: String, CaseIterable {
    case videoFrame = "Video Frame (Silent)"
    case photoCapture = "Photo Capture (Higher Quality)"
}

@MainActor
class SegmentationManager: ObservableObject {
    @Published var isEnabled: Bool = false
    @Published var pollingInterval: TimeInterval = 1.0 // Default 1 second
    @Published var currentPrompt: String = "object"
    @Published var lastResult: SegmentationResult?
    @Published var lastError: String?
    @Published var isProcessing: Bool = false
    @Published var source: SegmentationSource = .videoFrame // Default to silent

    private let falService: FalAIService
    private var pollingTask: Task<Void, Never>?
    private var pendingPhoto: UIImage?
    private var latestVideoFrame: UIImage?
    private var photoCaptureCallback: (() -> Void)?

    init(apiKey: String? = nil) {
        self.falService = FalAIService(apiKey: apiKey)
    }

    /// Set callback to request photo capture from the camera
    func setPhotoCaptureCallback(_ callback: @escaping () -> Void) {
        self.photoCaptureCallback = callback
    }

    /// Called when a camera photo is captured
    func onPhotoCaptured(_ photo: UIImage) {
        pendingPhoto = photo
    }

    /// Called with each video frame
    func updateVideoFrame(_ frame: UIImage) {
        latestVideoFrame = frame
    }

    func start() {
        guard !isEnabled else { return }
        isEnabled = true
        lastError = nil
        startPolling()
    }

    func stop() {
        isEnabled = false
        stopPolling()
    }

    func setPollingInterval(_ interval: TimeInterval) {
        pollingInterval = max(0.5, interval) // Minimum 500ms for photo captures
        if isEnabled {
            stopPolling()
            startPolling()
        }
    }

    func setPrompt(_ prompt: String) {
        currentPrompt = prompt
    }

    private func startPolling() {
        stopPolling()
        pollingTask = Task { [weak self] in
            while let self, self.isEnabled, !Task.isCancelled {
                switch self.source {
                case .photoCapture:
                    // Request a photo capture
                    self.photoCaptureCallback?()

                    // Wait a bit for the photo to arrive
                    try? await Task.sleep(nanoseconds: 300_000_000) // 300ms for photo capture

                    // Process the captured photo
                    await self.processImage(self.pendingPhoto)
                    self.pendingPhoto = nil

                    // Wait for the rest of the polling interval
                    let remainingWait = max(0, self.pollingInterval - 0.3)
                    try? await Task.sleep(nanoseconds: UInt64(remainingWait * 1_000_000_000))

                case .videoFrame:
                    // Process the latest video frame (silent)
                    await self.processImage(self.latestVideoFrame)

                    // Wait for the polling interval
                    try? await Task.sleep(nanoseconds: UInt64(self.pollingInterval * 1_000_000_000))
                }
            }
        }
    }

    private func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    private func processImage(_ image: UIImage?) async {
        guard let image = image, !isProcessing else { return }

        isProcessing = true
        defer { isProcessing = false }

        do {
            let response = try await falService.segment(image: image, prompt: currentPrompt)

            if let maskInfo = response.masks?.first ?? response.image {
                let maskImage = try? await falService.downloadImage(from: maskInfo.url)

                lastResult = SegmentationResult(
                    maskImage: maskImage,
                    maskURL: maskInfo.url,
                    score: response.scores?.first,
                    boundingBox: response.boxes?.first,
                    timestamp: Date()
                )
                lastError = nil
            }
        } catch FalAIError.requestInProgress {
            // Silently skip if a request is already in progress
        } catch {
            lastError = error.localizedDescription
        }
    }
}
