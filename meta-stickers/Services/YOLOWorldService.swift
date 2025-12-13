import Foundation
import CoreML
import Vision
import UIKit

/// Service for running YOLO-World object detection on-device
actor YOLOWorldService {
    // MARK: - Properties

    private var model: VNCoreMLModel?
    private var mlModel: MLModel?
    private var _isLoaded = false

    /// Pre-computed text embeddings for common prompts
    private var textEmbeddings: [String: [Float]] = [:]

    /// Classes the model was exported with (set during export)
    private var exportedClasses: [String] = []

    // MARK: - Configuration

    static let defaultInputSize = 640
    static let confidenceThreshold: Float = 0.25
    static let iouThreshold: Float = 0.45

    // MARK: - Public Interface

    var isLoaded: Bool {
        _isLoaded
    }

    /// Load the YOLO-World model
    func load() async throws {
        // Try to load the model from bundle
        let modelName = "YOLOWorldS" // or YOLOWorldM for better quality

        guard let modelURL = Bundle.main.url(forResource: modelName, withExtension: "mlmodelc") ??
                             Bundle.main.url(forResource: modelName, withExtension: "mlpackage") else {
            // Model not found - this is expected until you add the converted model
            print("⚠️ YOLO-World model not found in bundle. Add \(modelName).mlpackage to your project.")
            print("   Run the Python conversion script to generate the model.")
            throw SegmentationError.modelNotFound(modelName)
        }

        let config = MLModelConfiguration()
        config.computeUnits = .all // Use ANE + GPU + CPU

        do {
            mlModel = try await MLModel.load(contentsOf: modelURL, configuration: config)
            model = try VNCoreMLModel(for: mlModel!)
            _isLoaded = true
            print("✅ YOLO-World model loaded successfully")
        } catch {
            throw SegmentationError.inferenceFailed("Failed to load model: \(error.localizedDescription)")
        }

        // Load pre-computed text embeddings
        loadTextEmbeddings()
    }

    /// Detect objects matching the prompt
    func detect(image: CGImage, prompt: String, inputSize: Int = defaultInputSize) async throws -> [DetectedObject] {
        guard let model = model else {
            throw SegmentationError.modelNotLoaded
        }

        // Preprocess: resize with letterboxing
        guard let processedBuffer = preprocessImage(image, targetSize: inputSize) else {
            throw SegmentationError.preprocessingFailed
        }

        // Run inference
        let request = VNCoreMLRequest(model: model)
        request.imageCropAndScaleOption = .scaleFill

        let handler = VNImageRequestHandler(cvPixelBuffer: processedBuffer, options: [:])

        do {
            try handler.perform([request])
        } catch {
            throw SegmentationError.inferenceFailed(error.localizedDescription)
        }

        // Parse results
        return parseResults(request.results, prompt: prompt, originalSize: CGSize(width: image.width, height: image.height))
    }

    // MARK: - Preprocessing

    private func preprocessImage(_ image: CGImage, targetSize: Int) -> CVPixelBuffer? {
        let targetCGSize = CGSize(width: targetSize, height: targetSize)

        // Create pixel buffer
        var pixelBuffer: CVPixelBuffer?
        let attrs: [String: Any] = [
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
            kCVPixelBufferMetalCompatibilityKey as String: true
        ]

        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            targetSize,
            targetSize,
            kCVPixelFormatType_32BGRA,
            attrs as CFDictionary,
            &pixelBuffer
        )

        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            return nil
        }

        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }

        guard let context = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: targetSize,
            height: targetSize,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        ) else {
            return nil
        }

        // Calculate letterbox scaling
        let imageWidth = CGFloat(image.width)
        let imageHeight = CGFloat(image.height)
        let scale = min(CGFloat(targetSize) / imageWidth, CGFloat(targetSize) / imageHeight)

        let scaledWidth = imageWidth * scale
        let scaledHeight = imageHeight * scale
        let offsetX = (CGFloat(targetSize) - scaledWidth) / 2
        let offsetY = (CGFloat(targetSize) - scaledHeight) / 2

        // Fill with gray (letterbox padding)
        context.setFillColor(gray: 0.5, alpha: 1.0)
        context.fill(CGRect(x: 0, y: 0, width: targetSize, height: targetSize))

        // Draw scaled image centered
        context.draw(image, in: CGRect(x: offsetX, y: offsetY, width: scaledWidth, height: scaledHeight))

        return buffer
    }

    // MARK: - Postprocessing

    private func parseResults(_ results: [VNObservation]?, prompt: String, originalSize: CGSize) -> [DetectedObject] {
        guard let results = results else { return [] }

        var detections: [DetectedObject] = []

        // Handle VNRecognizedObjectObservation (standard YOLO output through Vision)
        if let objectObservations = results as? [VNRecognizedObjectObservation] {
            for observation in objectObservations {
                guard observation.confidence >= Self.confidenceThreshold else { continue }

                // Check if the detected class matches the prompt
                let matchesPrompt = observation.labels.contains { label in
                    label.identifier.lowercased().contains(prompt.lowercased()) ||
                    prompt.lowercased().contains(label.identifier.lowercased())
                }

                if matchesPrompt || prompt.isEmpty {
                    detections.append(DetectedObject(
                        boundingBox: observation.boundingBox,
                        confidence: observation.confidence,
                        label: observation.labels.first?.identifier ?? prompt
                    ))
                }
            }
        }

        // Handle raw MLMultiArray output (if model outputs raw tensors)
        if let coreMLResults = results as? [VNCoreMLFeatureValueObservation] {
            for observation in coreMLResults {
                if let multiArray = observation.featureValue.multiArrayValue {
                    let parsed = parseRawYOLOOutput(multiArray, prompt: prompt, originalSize: originalSize)
                    detections.append(contentsOf: parsed)
                }
            }
        }

        // Apply NMS
        return nonMaxSuppression(detections)
    }

    /// Parse raw YOLO output tensor
    /// Shape is typically [1, num_classes+4, num_anchors] or [1, num_anchors, num_classes+4]
    private func parseRawYOLOOutput(_ output: MLMultiArray, prompt: String, originalSize: CGSize) -> [DetectedObject] {
        // This depends on the exact model output format
        // YOLO-World outputs: [batch, 4 + num_classes, num_predictions]

        let shape = output.shape.map { $0.intValue }
        guard shape.count >= 2 else { return [] }

        var detections: [DetectedObject] = []

        // Common YOLO output parsing
        // Adjust based on your model's actual output shape
        let numPredictions = shape.last ?? 0
        let numChannels = shape.count > 2 ? shape[1] : shape[0]

        // Box format: [x_center, y_center, width, height, class_scores...]
        let numClasses = numChannels - 4

        guard numClasses > 0 else { return [] }

        for i in 0..<numPredictions {
            // Extract box coordinates (normalized)
            let xCenter = output[[0, 0, i] as [NSNumber]].floatValue
            let yCenter = output[[0, 1, i] as [NSNumber]].floatValue
            let width = output[[0, 2, i] as [NSNumber]].floatValue
            let height = output[[0, 3, i] as [NSNumber]].floatValue

            // Find max class score
            var maxScore: Float = 0
            var maxClassIndex = 0

            for c in 0..<numClasses {
                let score = output[[0, 4 + c, i] as [NSNumber]].floatValue
                if score > maxScore {
                    maxScore = score
                    maxClassIndex = c
                }
            }

            guard maxScore >= Self.confidenceThreshold else { continue }

            // Convert to corner format (Vision uses bottom-left origin)
            let x = CGFloat(xCenter - width / 2)
            let y = CGFloat(yCenter - height / 2)

            detections.append(DetectedObject(
                boundingBox: CGRect(x: x, y: y, width: CGFloat(width), height: CGFloat(height)),
                confidence: maxScore,
                label: exportedClasses.indices.contains(maxClassIndex) ? exportedClasses[maxClassIndex] : prompt
            ))
        }

        return detections
    }

    /// Non-Maximum Suppression to remove overlapping boxes
    private func nonMaxSuppression(_ boxes: [DetectedObject]) -> [DetectedObject] {
        guard !boxes.isEmpty else { return [] }

        let sorted = boxes.sorted { $0.confidence > $1.confidence }
        var selected: [DetectedObject] = []
        var active = [Bool](repeating: true, count: sorted.count)

        for i in 0..<sorted.count {
            guard active[i] else { continue }
            selected.append(sorted[i])

            for j in (i + 1)..<sorted.count {
                guard active[j] else { continue }
                if iou(sorted[i].boundingBox, sorted[j].boundingBox) > Self.iouThreshold {
                    active[j] = false
                }
            }
        }

        return selected
    }

    /// Calculate Intersection over Union
    private func iou(_ a: CGRect, _ b: CGRect) -> Float {
        let intersection = a.intersection(b)
        if intersection.isNull || intersection.isEmpty { return 0 }

        let intersectionArea = intersection.width * intersection.height
        let unionArea = a.width * a.height + b.width * b.height - intersectionArea

        guard unionArea > 0 else { return 0 }
        return Float(intersectionArea / unionArea)
    }

    // MARK: - Text Embeddings

    private func loadTextEmbeddings() {
        guard let url = Bundle.main.url(forResource: "TextEmbeddings", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let embeddings = try? JSONDecoder().decode([String: [Float]].self, from: data) else {
            print("⚠️ Text embeddings not found. Pre-computed prompt matching will be limited.")
            return
        }

        textEmbeddings = embeddings
        print("✅ Loaded \(embeddings.count) pre-computed text embeddings")
    }

    /// Check if we have a pre-computed embedding for this prompt
    func hasEmbedding(for prompt: String) -> Bool {
        textEmbeddings[prompt.lowercased()] != nil
    }

    /// Get available prompts with pre-computed embeddings
    func availablePrompts() -> [String] {
        Array(textEmbeddings.keys).sorted()
    }
}

// MARK: - Convenience Extensions

extension YOLOWorldService {
    /// Detect with UIImage input
    func detect(uiImage: UIImage, prompt: String, inputSize: Int = defaultInputSize) async throws -> [DetectedObject] {
        guard let cgImage = uiImage.cgImage else {
            throw SegmentationError.preprocessingFailed
        }
        return try await detect(image: cgImage, prompt: prompt, inputSize: inputSize)
    }
}
