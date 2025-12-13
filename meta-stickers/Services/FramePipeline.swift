import Foundation
import CoreGraphics
import Combine
import UIKit

/// Pipeline for processing video frames with throttled segmentation
@MainActor
final class FramePipeline: ObservableObject {
    // MARK: - Published State

    @Published private(set) var currentResults: [SegmentationResult] = []
    @Published private(set) var isProcessing = false
    @Published private(set) var isModelLoaded = false
    @Published private(set) var lastError: Error?
    @Published private(set) var inferenceTimeMs: Double = 0

    @Published var currentPrompt: String = ""
    @Published var quality: InferenceQuality = .balanced
    @Published var isEnabled = true

    // MARK: - Configuration

    /// Use mock service for testing without models
    var useMockService: Bool {
        didSet {
            Task { await switchService() }
        }
    }

    // MARK: - Private State

    private var segmentationService: any SegmentationServiceProtocol
    private var latestFrame: CGImage?
    private var processingTask: Task<Void, Never>?
    private var lastInferenceTime: Date = .distantPast

    private let processingQueue = DispatchQueue(label: "com.metastickers.framepipeline", qos: .userInitiated)

    // MARK: - Initialization

    init(useMock: Bool = false) {
        self.useMockService = useMock
        self.segmentationService = useMock ? MockSegmentationService() : SegmentationService()
    }

    // MARK: - Lifecycle

    func load() async {
        do {
            try await segmentationService.load()
            isModelLoaded = await segmentationService.isLoaded
            lastError = nil
        } catch {
            lastError = error
            isModelLoaded = false
            print("Failed to load segmentation service: \(error)")
        }
    }

    private func switchService() async {
        // Cancel any pending work
        processingTask?.cancel()
        processingTask = nil

        // Switch service
        segmentationService = useMockService ? MockSegmentationService() : SegmentationService()
        isModelLoaded = false

        // Reload
        await load()
    }

    // MARK: - Frame Processing

    /// Submit a new frame for processing
    func submitFrame(_ frame: CGImage) {
        guard isEnabled, isModelLoaded, !currentPrompt.isEmpty else { return }

        // Always keep the latest frame
        latestFrame = frame

        // Check if we should process
        let targetInterval = 1.0 / quality.targetFPS
        let elapsed = Date().timeIntervalSince(lastInferenceTime)

        guard elapsed >= targetInterval, !isProcessing else { return }

        // Start processing
        processLatestFrame()
    }

    /// Submit a UIImage frame
    func submitFrame(_ image: UIImage) {
        guard let cgImage = image.cgImage else { return }
        submitFrame(cgImage)
    }

    private func processLatestFrame() {
        guard let frame = latestFrame else { return }

        isProcessing = true
        latestFrame = nil
        lastInferenceTime = Date()

        let prompt = currentPrompt
        let currentQuality = quality

        processingTask = Task {
            let startTime = Date()

            do {
                let results = try await segmentationService.segment(
                    image: frame,
                    prompt: prompt,
                    quality: currentQuality
                )

                await MainActor.run {
                    self.currentResults = results
                    self.inferenceTimeMs = Date().timeIntervalSince(startTime) * 1000
                    self.lastError = nil
                    self.isProcessing = false
                }
            } catch SegmentationError.noDetections {
                // Not an error - just no objects found
                await MainActor.run {
                    self.currentResults = []
                    self.inferenceTimeMs = Date().timeIntervalSince(startTime) * 1000
                    self.lastError = nil
                    self.isProcessing = false
                }
            } catch {
                await MainActor.run {
                    self.lastError = error
                    self.isProcessing = false
                }
            }
        }
    }

    // MARK: - Single Frame Capture

    /// Process a single frame at best quality (for sticker capture)
    func captureSticker(from frame: CGImage) async -> [SegmentationResult] {
        guard isModelLoaded, !currentPrompt.isEmpty else { return [] }

        do {
            return try await segmentationService.segment(
                image: frame,
                prompt: currentPrompt,
                quality: .best
            )
        } catch {
            lastError = error
            return []
        }
    }

    /// Extract cutout images from results
    func extractCutouts(from frame: CGImage, results: [SegmentationResult]) -> [UIImage] {
        results.compactMap { result in
            result.extractCutout(from: frame, padding: 0.05)
        }
    }

    // MARK: - Cleanup

    func stop() {
        isEnabled = false
        processingTask?.cancel()
        processingTask = nil
        currentResults = []
    }

    func reset() {
        stop()
        currentPrompt = ""
        quality = .balanced
        isEnabled = true
    }
}

// MARK: - Notification for UI Updates

extension Notification.Name {
    static let segmentationResultsUpdated = Notification.Name("segmentationResultsUpdated")
}

// MARK: - SwiftUI Preview Support

extension FramePipeline {
    static var preview: FramePipeline {
        let pipeline = FramePipeline(useMock: true)
        pipeline.currentPrompt = "person"
        return pipeline
    }
}
