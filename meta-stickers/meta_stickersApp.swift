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

@main
struct meta_stickersApp: App {
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

            RegistrationView(viewModel: wearablesViewModel)
        }
        .modelContainer(sharedModelContainer)
    }
}
