//
//  MockURLSession.swift
//  meta-stickersTests
//

import Foundation
@testable import meta_stickers

/// Protocol for URL session abstraction (for testing)
protocol URLSessionProtocol {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
    func data(from url: URL) async throws -> (Data, URLResponse)
}

/// Extension to make URLSession conform to our protocol
extension URLSession: URLSessionProtocol {}

/// Mock URL session for testing network requests
class MockURLSession: URLSessionProtocol {
    var mockData: Data?
    var mockResponse: URLResponse?
    var mockError: Error?

    /// Tracks all requests made
    var requestHistory: [URLRequest] = []
    var urlHistory: [URL] = []

    /// Handler for dynamic responses based on request
    var requestHandler: ((URLRequest) -> (Data, URLResponse, Error?))?
    var urlHandler: ((URL) -> (Data, URLResponse, Error?))?

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        requestHistory.append(request)

        if let handler = requestHandler {
            let (data, response, error) = handler(request)
            if let error = error { throw error }
            return (data, response)
        }

        if let error = mockError {
            throw error
        }

        let response = mockResponse ?? HTTPURLResponse(
            url: request.url!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!

        return (mockData ?? Data(), response)
    }

    func data(from url: URL) async throws -> (Data, URLResponse) {
        urlHistory.append(url)

        if let handler = urlHandler {
            let (data, response, error) = handler(url)
            if let error = error { throw error }
            return (data, response)
        }

        if let error = mockError {
            throw error
        }

        let response = mockResponse ?? HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!

        return (mockData ?? Data(), response)
    }

    /// Creates a successful HTTP response
    static func successResponse(url: URL, statusCode: Int = 200) -> HTTPURLResponse {
        HTTPURLResponse(
            url: url,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
    }

    /// Resets all tracking data
    func reset() {
        mockData = nil
        mockResponse = nil
        mockError = nil
        requestHistory.removeAll()
        urlHistory.removeAll()
        requestHandler = nil
        urlHandler = nil
    }
}

/// Mock network error for testing
enum MockNetworkError: Error {
    case connectionFailed
    case timeout
    case invalidResponse
}
