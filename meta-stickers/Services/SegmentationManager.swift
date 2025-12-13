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

@MainActor
class SegmentationManager: ObservableObject {
    @Published var isEnabled: Bool = false
    @Published var pollingInterval: TimeInterval = 1.0 // Default 1 second
    @Published var currentPrompt: String = "object"
    @Published var lastResult: SegmentationResult?
    @Published var lastError: String?
    @Published var isProcessing: Bool = false

    private let falService: FalAIService
    private var pollingTask: Task<Void, Never>?
    private var latestFrame: UIImage?

    init(apiKey: String? = nil) {
        self.falService = FalAIService(apiKey: apiKey)
    }

    func updateFrame(_ frame: UIImage) {
        latestFrame = frame
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
        pollingInterval = max(0.1, interval) // Minimum 100ms
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
                await self.processCurrentFrame()
                try? await Task.sleep(nanoseconds: UInt64(self.pollingInterval * 1_000_000_000))
            }
        }
    }

    private func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    private func processCurrentFrame() async {
        guard let frame = latestFrame, !isProcessing else { return }

        isProcessing = true
        defer { isProcessing = false }

        do {
            let response = try await falService.segment(image: frame, prompt: currentPrompt)

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
