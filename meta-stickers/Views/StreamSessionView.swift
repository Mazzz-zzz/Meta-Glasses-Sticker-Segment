//
//  StreamSessionView.swift
//  meta-stickers
//

import MWDATCore
import SwiftUI
import SwiftData

struct StreamSessionView: View {
    let wearables: WearablesInterface
    @ObservedObject private var wearablesViewModel: WearablesViewModel
    @StateObject private var viewModel: StreamSessionViewModel
    @Environment(\.modelContext) private var modelContext
    @State private var appSettings: AppSettings?
    @State private var dataManager: StickerDataManager?

    init(wearables: WearablesInterface, wearablesVM: WearablesViewModel) {
        self.wearables = wearables
        self.wearablesViewModel = wearablesVM
        // Note: dataManager will be set in onAppear since we need modelContext from environment
        self._viewModel = StateObject(wrappedValue: StreamSessionViewModel(
            wearables: wearables,
            falAPIKey: Config.falAPIKey
        ))
    }

    var body: some View {
        ZStack {
            if viewModel.isStreaming {
                StreamView(viewModel: viewModel, wearablesVM: wearablesViewModel, appSettings: appSettings)
            } else {
                NonStreamView(viewModel: viewModel, wearablesVM: wearablesViewModel)
            }
        }
        .onAppear {
            setupDataManager()
            loadAndApplySettings()
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK") {
                viewModel.dismissError()
            }
        } message: {
            Text(viewModel.errorMessage)
        }
    }

    private func setupDataManager() {
        let manager = StickerDataManager(modelContext: modelContext)
        self.dataManager = manager
        viewModel.segmentationManager.setDataManager(manager)
    }

    private func loadAndApplySettings() {
        guard let dataManager = dataManager else { return }

        // Load or create settings
        let settings = dataManager.getOrCreateSettings()
        self.appSettings = settings

        // Apply saved settings to SegmentationManager
        let segManager = viewModel.segmentationManager
        segManager.pollingInterval = settings.pollingInterval
        segManager.currentPrompt = settings.currentPrompt
        segManager.autoSaveEnabled = settings.autoSaveStickers

        // Apply segmentation source
        if settings.segmentationSource == "photoCapture" {
            segManager.source = .photoCapture
        } else {
            segManager.source = .videoFrame
        }

        print("[Settings] Loaded - interval: \(settings.pollingInterval), prompt: \(settings.currentPrompt), autoSave: \(settings.autoSaveStickers)")
    }
}
