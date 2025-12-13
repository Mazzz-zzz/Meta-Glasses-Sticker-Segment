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

            if httpResponse.statusCode == 200 {
                let decoder = JSONDecoder()
                return try decoder.decode(SAM3Response.self, from: data)
            } else if httpResponse.statusCode == 202 {
                let queueResponse = try JSONDecoder().decode(QueueSubmitResponse.self, from: data)
                return try await pollForResult(requestId: queueResponse.request_id)
            } else {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw FalAIError.apiError("HTTP \(httpResponse.statusCode): \(errorMessage)")
            }
        } catch let error as FalAIError {
            throw error
        } catch let error as DecodingError {
            throw FalAIError.decodingError(error)
        } catch {
            throw FalAIError.networkError(error)
        }
    }

    private func pollForResult(requestId: String, maxAttempts: Int = 30) async throws -> SAM3Response {
        let statusURL = "https://queue.fal.run/fal-ai/sam-3/image/requests/\(requestId)/status"
        let resultURL = "https://queue.fal.run/fal-ai/sam-3/image/requests/\(requestId)"

        for attempt in 0..<maxAttempts {
            try await Task.sleep(nanoseconds: 500_000_000) // 500ms

            var statusRequest = URLRequest(url: URL(string: statusURL)!)
            statusRequest.setValue("Key \(apiKey)", forHTTPHeaderField: "Authorization")

            let (statusData, _) = try await URLSession.shared.data(for: statusRequest)
            let status = try JSONDecoder().decode(QueueStatusResponse.self, from: statusData)

            if status.status == "COMPLETED" {
                var resultRequest = URLRequest(url: URL(string: resultURL)!)
                resultRequest.setValue("Key \(apiKey)", forHTTPHeaderField: "Authorization")

                let (resultData, _) = try await URLSession.shared.data(for: resultRequest)
                return try JSONDecoder().decode(SAM3Response.self, from: resultData)
            } else if status.status == "FAILED" {
                throw FalAIError.apiError("Request failed")
            }
        }

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

        return image
    }
}
