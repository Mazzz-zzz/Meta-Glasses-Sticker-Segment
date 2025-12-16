//
//  SegmentationManager.swift
//  meta-stickers
//

import Foundation
import UIKit
import Combine

struct SegmentationResult: Identifiable {
    let id = UUID()
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
    @Published var stickerHistory: [SegmentationResult] = []

    // Database integration
    @Published var autoSaveEnabled: Bool = true
    private var dataManager: StickerDataManager?

    // Style processing
    private let styleProcessor = StickerStyleProcessor()
    private var styleSettings: StickerStyleSettings = .default

    private let maxStickerHistory = 50 // Keep last 50 stickers

    private let falService: FalAIService
    private var pollingTask: Task<Void, Never>?
    private var pendingPhoto: UIImage?
    private var latestVideoFrame: UIImage?
    private var photoCaptureCallback: (() -> Void)?

    init(apiKey: String? = nil, dataManager: StickerDataManager? = nil) {
        self.falService = FalAIService(apiKey: apiKey)
        self.dataManager = dataManager
    }

    /// Updates the style settings used when processing stickers
    func updateStyleSettings(from appSettings: AppSettings?) {
        self.styleSettings = StickerStyleSettings(from: appSettings)
    }

    /// Sets the data manager for persisting stickers
    func setDataManager(_ manager: StickerDataManager) {
        self.dataManager = manager
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

    func clearHistory() {
        stickerHistory.removeAll()
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
        guard let image = image, !isProcessing else {
            print("[SAM3] Skipping - no image or request in progress")
            return
        }

        isProcessing = true
        defer { isProcessing = false }

        do {
            print("[SAM3] Sending image to FAL API...")
            let response = try await falService.segment(image: image, prompt: currentPrompt)
            print("[SAM3] Response received - masks: \(response.masks?.count ?? 0), image: \(response.image != nil)")

            if let maskInfo = response.masks?.first ?? response.image {
                print("[SAM3] Downloading mask from: \(maskInfo.url)")
                do {
                    let rawMaskImage = try await falService.downloadImage(from: maskInfo.url)
                    print("[SAM3] Mask downloaded successfully")

                    // Apply style settings to the sticker
                    let styledImage = styleProcessor.applyStyle(to: rawMaskImage, settings: styleSettings)
                    print("[SAM3] Style applied: \(styleSettings.style.rawValue)")

                    let result = SegmentationResult(
                        maskImage: styledImage,
                        maskURL: maskInfo.url,
                        score: response.scores?.first,
                        boundingBox: response.boxes?.first,
                        timestamp: Date()
                    )
                    lastResult = result
                    lastError = nil

                    // Add to in-memory sticker history
                    stickerHistory.insert(result, at: 0)
                    // Keep only the most recent stickers in memory
                    if stickerHistory.count > maxStickerHistory {
                        stickerHistory = Array(stickerHistory.prefix(maxStickerHistory))
                    }
                    print("[SAM3] Sticker added to history. Total: \(stickerHistory.count)")

                    // Auto-save to database if enabled (save styled image)
                    if autoSaveEnabled, let dataManager = dataManager {
                        if let savedSticker = dataManager.saveSticker(
                            image: styledImage,
                            prompt: currentPrompt,
                            score: response.scores?.first,
                            boundingBox: response.boxes?.first
                        ) {
                            print("[SAM3] Sticker saved to database: \(savedSticker.id)")
                        }
                    }
                } catch {
                    print("[SAM3] Failed to download mask: \(error)")
                    lastError = "Failed to download mask: \(error.localizedDescription)"
                }
            } else {
                print("[SAM3] No masks or image in response")
                lastError = "No segmentation result in response"
            }
        } catch FalAIError.requestInProgress {
            print("[SAM3] Request already in progress, skipping")
        } catch {
            print("[SAM3] Error: \(error)")
            lastError = error.localizedDescription
        }
    }
}
