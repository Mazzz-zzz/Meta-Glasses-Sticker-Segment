//
//  Item.swift
//  meta-stickers
//
//  Created by Almaz Khalilov on 13/12/2025.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
