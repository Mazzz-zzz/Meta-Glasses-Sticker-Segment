import Foundation
import CoreML
import Vision
import UIKit

/// Combined segmentation service using YOLO-World for detection + MobileSAM for masks
actor SegmentationService: SegmentationServiceProtocol {
    // MARK: - Dependencies

    private let yoloService = YOLOWorldService()
    private var samEncoder: MLModel?
    private var samDecoder: MLModel?

    // MARK: - State

    private var _isLoaded = false
    private var samAvailable = false

    /// Cached image embedding for SAM (reuse across multiple box prompts)
    private var cachedEmbedding: (imageHash: Int, embedding: MLMultiArray)?

    // MARK: - Configuration

    static let samInputSize = 1024  // MobileSAM expects 1024x1024

    // MARK: - Public Interface

    var isLoaded: Bool {
        _isLoaded
    }

    func load() async throws {
        // Load YOLO-World (required)
        do {
            try await yoloService.load()
        } catch SegmentationError.modelNotFound {
            // YOLO not available - will fall back to mock
            print("⚠️ YOLO-World not available. Using mock detections.")
        }

        // Load MobileSAM (optional - for mask refinement)
        await loadSAMModels()

        _isLoaded = true
    }

    private func loadSAMModels() async {
        let config = MLModelConfiguration()
        config.computeUnits = .all

        // Try to load SAM encoder
        if let encoderURL = Bundle.main.url(forResource: "MobileSAM_Encoder", withExtension: "mlmodelc") ??
                           Bundle.main.url(forResource: "MobileSAM_Encoder", withExtension: "mlpackage") {
            do {
                samEncoder = try await MLModel.load(contentsOf: encoderURL, configuration: config)
                print("✅ MobileSAM encoder loaded")
            } catch {
                print("⚠️ Failed to load MobileSAM encoder: \(error)")
            }
        }

        // Try to load SAM decoder
        if let decoderURL = Bundle.main.url(forResource: "MobileSAM_Decoder", withExtension: "mlmodelc") ??
                           Bundle.main.url(forResource: "MobileSAM_Decoder", withExtension: "mlpackage") {
            do {
                samDecoder = try await MLModel.load(contentsOf: decoderURL, configuration: config)
                print("✅ MobileSAM decoder loaded")
            } catch {
                print("⚠️ Failed to load MobileSAM decoder: \(error)")
            }
        }

        samAvailable = samEncoder != nil && samDecoder != nil

        if !samAvailable {
            print("⚠️ MobileSAM not available. Masks will be rectangular (box-based).")
        }
    }

    // MARK: - Detection

    func detect(image: CGImage, prompt: String) async throws -> [DetectedObject] {
        guard _isLoaded else { throw SegmentationError.modelNotLoaded }

        // Try YOLO-World first
        if await yoloService.isLoaded {
            return try await yoloService.detect(image: image, prompt: prompt)
        }

        // Fallback: return mock detections
        return generateFallbackDetections(for: prompt, imageSize: CGSize(width: image.width, height: image.height))
    }

    // MARK: - Segmentation

    func segment(image: CGImage, prompt: String, quality: InferenceQuality) async throws -> [SegmentationResult] {
        guard _isLoaded else { throw SegmentationError.modelNotLoaded }

        // Step 1: Detect objects
        let inputSize = quality.yoloInputSize
        var detections: [DetectedObject]

        if await yoloService.isLoaded {
            detections = try await yoloService.detect(image: image, prompt: prompt, inputSize: inputSize)
        } else {
            detections = generateFallbackDetections(for: prompt, imageSize: CGSize(width: image.width, height: image.height))
        }

        guard !detections.isEmpty else {
            throw SegmentationError.noDetections
        }

        // Step 2: Generate masks
        let frameSize = CGSize(width: image.width, height: image.height)

        if quality.useSAM && samAvailable {
            // Use MobileSAM for high-quality masks
            return try await generateSAMMasks(for: detections, image: image, prompt: prompt)
        } else {
            // Use box-based masks (faster, lower quality)
            return detections.map { detection in
                SegmentationResult(
                    mask: createBoxMask(for: detection.boundingBox, imageSize: frameSize),
                    boundingBox: detection.boundingBox,
                    confidence: detection.confidence,
                    prompt: prompt,
                    frameSize: frameSize
                )
            }
        }
    }

    // MARK: - SAM Mask Generation

    private func generateSAMMasks(for detections: [DetectedObject], image: CGImage, prompt: String) async throws -> [SegmentationResult] {
        guard let encoder = samEncoder, let decoder = samDecoder else {
            throw SegmentationError.modelNotLoaded
        }

        let frameSize = CGSize(width: image.width, height: image.height)

        // Encode image once (expensive operation)
        let imageHash = image.hashValue
        let embedding: MLMultiArray

        if let cached = cachedEmbedding, cached.imageHash == imageHash {
            embedding = cached.embedding
        } else {
            embedding = try await encodeImage(image, with: encoder)
            cachedEmbedding = (imageHash, embedding)
        }

        // Decode mask for each detection
        var results: [SegmentationResult] = []

        for detection in detections.prefix(5) { // Limit to top 5
            do {
                let mask = try await decodeMask(
                    embedding: embedding,
                    box: detection.boundingBox,
                    imageSize: frameSize,
                    decoder: decoder
                )

                results.append(SegmentationResult(
                    mask: mask,
                    boundingBox: detection.boundingBox,
                    confidence: detection.confidence,
                    prompt: prompt,
                    frameSize: frameSize
                ))
            } catch {
                print("Failed to generate mask for detection: \(error)")
                // Fallback to box mask
                results.append(SegmentationResult(
                    mask: createBoxMask(for: detection.boundingBox, imageSize: frameSize),
                    boundingBox: detection.boundingBox,
                    confidence: detection.confidence,
                    prompt: prompt,
                    frameSize: frameSize
                ))
            }
        }

        return results
    }

    private func encodeImage(_ image: CGImage, with encoder: MLModel) async throws -> MLMultiArray {
        // Preprocess image to SAM input size
        guard let pixelBuffer = preprocessForSAM(image) else {
            throw SegmentationError.preprocessingFailed
        }

        // Create input
        let inputName = encoder.modelDescription.inputDescriptionsByName.keys.first ?? "image"

        guard let input = try? MLDictionaryFeatureProvider(dictionary: [
            inputName: MLFeatureValue(pixelBuffer: pixelBuffer)
        ]) else {
            throw SegmentationError.preprocessingFailed
        }

        // Run encoder
        let output = try encoder.prediction(from: input)

        // Get embedding
        let embeddingName = encoder.modelDescription.outputDescriptionsByName.keys.first ?? "embedding"
        guard let embedding = output.featureValue(for: embeddingName)?.multiArrayValue else {
            throw SegmentationError.inferenceFailed("No embedding output")
        }

        return embedding
    }

    private func decodeMask(embedding: MLMultiArray, box: CGRect, imageSize: CGSize, decoder: MLModel) async throws -> CGImage {
        // Convert box to SAM format (xyxy, scaled to 1024)
        let scale = CGFloat(Self.samInputSize)
        let boxArray = try MLMultiArray(shape: [1, 4], dataType: .float32)
        boxArray[[0, 0] as [NSNumber]] = NSNumber(value: Float(box.minX * scale))
        boxArray[[0, 1] as [NSNumber]] = NSNumber(value: Float(box.minY * scale))
        boxArray[[0, 2] as [NSNumber]] = NSNumber(value: Float(box.maxX * scale))
        boxArray[[0, 3] as [NSNumber]] = NSNumber(value: Float(box.maxY * scale))

        // Create decoder input
        let inputDict: [String: MLFeatureValue] = [
            "image_embeddings": MLFeatureValue(multiArray: embedding),
            "boxes": MLFeatureValue(multiArray: boxArray)
        ]

        let input = try MLDictionaryFeatureProvider(dictionary: inputDict)

        // Run decoder
        let output = try decoder.prediction(from: input)

        // Get mask
        let maskName = decoder.modelDescription.outputDescriptionsByName.keys.first ?? "masks"
        guard let maskArray = output.featureValue(for: maskName)?.multiArrayValue else {
            throw SegmentationError.maskGenerationFailed
        }

        // Convert MLMultiArray to CGImage
        return try multiArrayToMask(maskArray, targetSize: imageSize)
    }

    private func preprocessForSAM(_ image: CGImage) -> CVPixelBuffer? {
        let targetSize = Self.samInputSize

        var pixelBuffer: CVPixelBuffer?
        let attrs: [String: Any] = [
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
        ]

        CVPixelBufferCreate(
            kCFAllocatorDefault,
            targetSize,
            targetSize,
            kCVPixelFormatType_32BGRA,
            attrs as CFDictionary,
            &pixelBuffer
        )

        guard let buffer = pixelBuffer else { return nil }

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

        // Scale to fit
        let scale = min(CGFloat(targetSize) / CGFloat(image.width),
                       CGFloat(targetSize) / CGFloat(image.height))
        let scaledWidth = CGFloat(image.width) * scale
        let scaledHeight = CGFloat(image.height) * scale
        let offsetX = (CGFloat(targetSize) - scaledWidth) / 2
        let offsetY = (CGFloat(targetSize) - scaledHeight) / 2

        context.setFillColor(gray: 0, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: targetSize, height: targetSize))
        context.draw(image, in: CGRect(x: offsetX, y: offsetY, width: scaledWidth, height: scaledHeight))

        return buffer
    }

    private func multiArrayToMask(_ array: MLMultiArray, targetSize: CGSize) throws -> CGImage {
        // Get mask dimensions from array
        let shape = array.shape.map { $0.intValue }
        guard shape.count >= 2 else {
            throw SegmentationError.maskGenerationFailed
        }

        let height = shape[shape.count - 2]
        let width = shape[shape.count - 1]

        // Create grayscale image from mask
        var pixels = [UInt8](repeating: 0, count: width * height)

        for y in 0..<height {
            for x in 0..<width {
                let index: [NSNumber]
                if shape.count == 4 {
                    index = [0, 0, y, x] as [NSNumber]
                } else if shape.count == 3 {
                    index = [0, y, x] as [NSNumber]
                } else {
                    index = [y, x] as [NSNumber]
                }

                let value = array[index].floatValue
                // Threshold at 0 (SAM outputs logits)
                pixels[y * width + x] = value > 0 ? 255 : 0
            }
        }

        // Create CGImage
        guard let provider = CGDataProvider(data: Data(pixels) as CFData),
              let cgImage = CGImage(
                width: width,
                height: height,
                bitsPerComponent: 8,
                bitsPerPixel: 8,
                bytesPerRow: width,
                space: CGColorSpaceCreateDeviceGray(),
                bitmapInfo: CGBitmapInfo(rawValue: 0),
                provider: provider,
                decode: nil,
                shouldInterpolate: true,
                intent: .defaultIntent
              ) else {
            throw SegmentationError.maskGenerationFailed
        }

        return cgImage
    }

    // MARK: - Fallback Methods

    private func generateFallbackDetections(for prompt: String, imageSize: CGSize) -> [DetectedObject] {
        // Return a centered detection for testing
        [DetectedObject(
            boundingBox: CGRect(x: 0.25, y: 0.25, width: 0.5, height: 0.5),
            confidence: 0.8,
            label: prompt
        )]
    }

    private func createBoxMask(for bbox: CGRect, imageSize: CGSize) -> CGImage {
        let width = max(1, Int(imageSize.width * bbox.width))
        let height = max(1, Int(imageSize.height * bbox.height))

        var pixels = [UInt8](repeating: 255, count: width * height)

        guard let provider = CGDataProvider(data: Data(pixels) as CFData),
              let cgImage = CGImage(
                width: width,
                height: height,
                bitsPerComponent: 8,
                bitsPerPixel: 8,
                bytesPerRow: width,
                space: CGColorSpaceCreateDeviceGray(),
                bitmapInfo: CGBitmapInfo(rawValue: 0),
                provider: provider,
                decode: nil,
                shouldInterpolate: false,
                intent: .defaultIntent
              ) else {
            // Return 1x1 white pixel as fallback
            let pixel: [UInt8] = [255]
            let fallbackProvider = CGDataProvider(data: Data(pixel) as CFData)!
            return CGImage(
                width: 1, height: 1,
                bitsPerComponent: 8, bitsPerPixel: 8, bytesPerRow: 1,
                space: CGColorSpaceCreateDeviceGray(),
                bitmapInfo: CGBitmapInfo(rawValue: 0),
                provider: fallbackProvider,
                decode: nil, shouldInterpolate: false, intent: .defaultIntent
            )!
        }

        return cgImage
    }
}
