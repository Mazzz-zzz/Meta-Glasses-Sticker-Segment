//
//  FalAIService.swift
//  meta-stickers
//

import Foundation
import UIKit

struct SAM3Request: Encodable {
    let image_url: String
    let prompt: String
    let apply_mask: Bool
    let output_format: String
    let sync_mode: Bool

    init(imageDataURI: String, prompt: String = "object", applyMask: Bool = true) {
        self.image_url = imageDataURI
        self.prompt = prompt
        self.apply_mask = applyMask
        self.output_format = "png"
        self.sync_mode = true
    }
}

struct SAM3Response: Decodable {
    let image: SAM3Image?
    let masks: [SAM3Image]?
    let scores: [Float]?
    let boxes: [[Float]]?
}

struct SAM3Image: Decodable {
    let url: String
    let content_type: String?
    let file_name: String?
    let file_size: Int?
    let width: Int?
    let height: Int?
}

struct QueueSubmitResponse: Decodable {
    let request_id: String
    let response_url: String?
    let status_url: String?
    let cancel_url: String?
}

struct QueueStatusResponse: Decodable {
    let status: String
    let response_url: String?
}

enum FalAIError: Error, LocalizedError {
    case invalidAPIKey
    case invalidImage
    case networkError(Error)
    case decodingError(Error)
    case apiError(String)
    case timeout
    case requestInProgress

    var errorDescription: String? {
        switch self {
        case .invalidAPIKey:
            return "Invalid or missing FAL_KEY API key"
        case .invalidImage:
            return "Failed to encode image"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .apiError(let message):
            return "API error: \(message)"
        case .timeout:
            return "Request timed out"
        case .requestInProgress:
            return "A request is already in progress"
        }
    }
}

actor FalAIService {
    private let apiKey: String
    private let baseURL = "https://queue.fal.run/fal-ai/sam-3/image"
    private var isRequestInProgress = false

    init(apiKey: String? = nil) {
        self.apiKey = apiKey ?? ProcessInfo.processInfo.environment["FAL_KEY"] ?? ""
    }

    func segment(image: UIImage, prompt: String = "object") async throws -> SAM3Response {
        guard !apiKey.isEmpty else {
            throw FalAIError.invalidAPIKey
        }

        guard !isRequestInProgress else {
            throw FalAIError.requestInProgress
        }

        isRequestInProgress = true
        defer { isRequestInProgress = false }

        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw FalAIError.invalidImage
        }

        let base64String = imageData.base64EncodedString()
        let dataURI = "data:image/jpeg;base64,\(base64String)"

        let request = SAM3Request(imageDataURI: dataURI, prompt: prompt)

        var urlRequest = URLRequest(url: URL(string: baseURL)!)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Key \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.timeoutInterval = 30

        let encoder = JSONEncoder()
        urlRequest.httpBody = try encoder.encode(request)

        do {
            let (data, response) = try await URLSession.shared.data(for: urlRequest)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw FalAIError.networkError(NSError(domain: "FalAI", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"]))
            }

            print("[FalAI] HTTP Status: \(httpResponse.statusCode)")
            if let responseStr = String(data: data, encoding: .utf8) {
                print("[FalAI] Response: \(responseStr.prefix(500))...")
            }

            if httpResponse.statusCode == 200 || httpResponse.statusCode == 202 {
                // Check if this is a queue response (has status field indicating IN_QUEUE)
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let status = json["status"] as? String,
                   status == "IN_QUEUE",
                   let requestId = json["request_id"] as? String {
                    print("[FalAI] Queued - request_id: \(requestId)")
                    return try await pollForResult(requestId: requestId)
                }

                // Otherwise it's a direct result
                let decoder = JSONDecoder()
                let result = try decoder.decode(SAM3Response.self, from: data)
                print("[FalAI] Decoded - masks: \(result.masks?.count ?? 0), image: \(result.image?.url ?? "nil")")
                return result
            } else {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw FalAIError.apiError("HTTP \(httpResponse.statusCode): \(errorMessage)")
            }
        } catch let error as FalAIError {
            throw error
        } catch let error as DecodingError {
            print("[FalAI] Decoding error: \(error)")
            throw FalAIError.decodingError(error)
        } catch {
            throw FalAIError.networkError(error)
        }
    }

    private func pollForResult(requestId: String, maxAttempts: Int = 30) async throws -> SAM3Response {
        let statusURL = "https://queue.fal.run/fal-ai/sam-3/requests/\(requestId)/status"
        let resultURL = "https://queue.fal.run/fal-ai/sam-3/requests/\(requestId)"

        for attempt in 0..<maxAttempts {
            try await Task.sleep(nanoseconds: 500_000_000) // 500ms

            var statusRequest = URLRequest(url: URL(string: statusURL)!)
            statusRequest.setValue("Key \(apiKey)", forHTTPHeaderField: "Authorization")

            let (statusData, _) = try await URLSession.shared.data(for: statusRequest)
            let status = try JSONDecoder().decode(QueueStatusResponse.self, from: statusData)
            print("[FalAI] Poll \(attempt + 1)/\(maxAttempts) - Status: \(status.status)")

            if status.status == "COMPLETED" {
                var resultRequest = URLRequest(url: URL(string: resultURL)!)
                resultRequest.setValue("Key \(apiKey)", forHTTPHeaderField: "Authorization")

                let (resultData, _) = try await URLSession.shared.data(for: resultRequest)
                if let responseStr = String(data: resultData, encoding: .utf8) {
                    print("[FalAI] Result: \(responseStr.prefix(500))...")
                }
                let result = try JSONDecoder().decode(SAM3Response.self, from: resultData)
                print("[FalAI] Poll complete - masks: \(result.masks?.count ?? 0), image: \(result.image?.url ?? "nil")")
                return result
            } else if status.status == "FAILED" {
                print("[FalAI] Request FAILED")
                throw FalAIError.apiError("Request failed")
            }
        }

        print("[FalAI] Timeout after \(maxAttempts) attempts")
        throw FalAIError.timeout
    }

    func downloadImage(from urlString: String) async throws -> UIImage {
        guard let url = URL(string: urlString) else {
            throw FalAIError.apiError("Invalid image URL")
        }

        let (data, _) = try await URLSession.shared.data(from: url)

        guard let image = UIImage(data: data) else {
            throw FalAIError.apiError("Failed to create image from data")
        }

        // Process the image: crop to content and ensure transparency
        return image.cropToOpaqueContent() ?? image
    }
}

// MARK: - Image Processing Extensions
extension UIImage {
    /// Crops the image to the bounding box of non-transparent pixels
    func cropToOpaqueContent() -> UIImage? {
        guard let cgImage = self.cgImage else { return nil }

        let width = cgImage.width
        let height = cgImage.height

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        guard let pixelData = context.data else { return nil }
        let data = pixelData.bindMemory(to: UInt8.self, capacity: width * height * 4)

        var minX = width
        var minY = height
        var maxX = 0
        var maxY = 0

        // Find bounding box of non-transparent pixels
        for y in 0..<height {
            for x in 0..<width {
                let pixelIndex = (y * width + x) * 4
                let alpha = data[pixelIndex + 3]

                // Consider pixel opaque if alpha > threshold (handle anti-aliasing)
                if alpha > 10 {
                    minX = min(minX, x)
                    minY = min(minY, y)
                    maxX = max(maxX, x)
                    maxY = max(maxY, y)
                }
            }
        }

        // Check if we found any opaque pixels
        guard minX < maxX && minY < maxY else { return self }

        // Add small padding
        let padding = 4
        minX = max(0, minX - padding)
        minY = max(0, minY - padding)
        maxX = min(width - 1, maxX + padding)
        maxY = min(height - 1, maxY + padding)

        let cropRect = CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)

        guard let croppedCGImage = cgImage.cropping(to: cropRect) else { return self }

        return UIImage(cgImage: croppedCGImage, scale: self.scale, orientation: self.imageOrientation)
    }
}
