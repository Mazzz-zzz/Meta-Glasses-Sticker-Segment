//
//  Config.swift
//  meta-stickers
//

import Foundation

enum Config {
    /// FAL AI API Key
    /// Priority: Secrets.swift > Environment variable > Info.plist
    static var falAPIKey: String? {
        // First try Secrets.swift (gitignored)
        let secretsKey = Secrets.falAPIKey
        if secretsKey != "YOUR_FAL_API_KEY_HERE" && !secretsKey.isEmpty {
            return secretsKey
        }

        // Then try environment variable
        if let envKey = ProcessInfo.processInfo.environment["FAL_KEY"], !envKey.isEmpty {
            return envKey
        }

        // Finally try Info.plist
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
