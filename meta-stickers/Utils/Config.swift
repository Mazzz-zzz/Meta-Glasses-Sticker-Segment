//
//  Config.swift
//  meta-stickers
//

import Foundation

enum Config {
    /// FAL AI API Key
    /// Priority: Environment variable > Info.plist
    static var falAPIKey: String? {
        // Try environment variable
        if let envKey = ProcessInfo.processInfo.environment["FAL_KEY"], !envKey.isEmpty {
            return envKey
        }

        // Fallback to Info.plist
        if let plistKey = Bundle.main.infoDictionary?["FAL_KEY"] as? String, !plistKey.isEmpty {
            return plistKey
        }

        return nil
    }

    /// Default segmentation polling interval in seconds
    static let defaultPollingInterval: TimeInterval = 1.0

    /// Default segmentation prompt
    static let defaultSegmentationPrompt: String = "object"
}
