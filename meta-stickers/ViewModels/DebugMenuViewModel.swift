//
//  DebugMenuViewModel.swift
//  meta-stickers
//

#if DEBUG
import Combine
import MWDATMockDevice
import SwiftUI

@MainActor
class DebugMenuViewModel: ObservableObject {
    @Published public var showDebugMenu: Bool = false
    let mockDeviceKit: any MockDeviceKitInterface

    init(mockDeviceKit: any MockDeviceKitInterface) {
        self.mockDeviceKit = mockDeviceKit
    }

    func toggleDebugMenu() {
        showDebugMenu.toggle()
    }
}
#endif
