//
//  meta_stickersApp.swift
//  meta-stickers
//
//  Created by Almaz Khalilov on 13/12/2025.
//

import Foundation
import MWDATCore
import SwiftUI
import SwiftData

#if DEBUG
import MWDATMockDevice
#endif

@main
struct meta_stickersApp: App {
    #if DEBUG
    @StateObject private var debugMenuViewModel = DebugMenuViewModel(mockDeviceKit: MockDeviceKit.shared)
    #endif

    private let wearables: WearablesInterface
    @StateObject private var wearablesViewModel: WearablesViewModel

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Sticker.self,
            StickerCollection.self,
            AppSettings.self,
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    init() {
        do {
            try Wearables.configure()
        } catch {
            #if DEBUG
            NSLog("[meta-stickers] Failed to configure Wearables SDK: \(error)")
            #endif
        }
        let wearables = Wearables.shared
        self.wearables = wearables
        self._wearablesViewModel = StateObject(wrappedValue: WearablesViewModel(wearables: wearables))
    }

    var body: some Scene {
        WindowGroup {
            MainAppView(wearables: Wearables.shared, viewModel: wearablesViewModel)
                .alert("Error", isPresented: $wearablesViewModel.showError) {
                    Button("OK") {
                        wearablesViewModel.dismissError()
                    }
                } message: {
                    Text(wearablesViewModel.errorMessage)
                }
                #if DEBUG
                .sheet(isPresented: $debugMenuViewModel.showDebugMenu) {
                    MockDeviceDebugView(mockDeviceKit: debugMenuViewModel.mockDeviceKit)
                }
                .overlay {
                    DebugMenuView(debugMenuViewModel: debugMenuViewModel)
                }
                #endif

            RegistrationView(viewModel: wearablesViewModel)
        }
        .modelContainer(sharedModelContainer)
    }
}
