//
//  TabContainerView.swift
//  meta-stickers
//

import MWDATCore
import SwiftUI
import SwiftData

enum AppTab: String, CaseIterable {
    case stream = "Stream"
    case library = "Library"
    case settings = "Settings"
}

struct TabContainerView: View {
    let wearables: WearablesInterface
    @ObservedObject var wearablesVM: WearablesViewModel
    @StateObject private var streamViewModel: StreamSessionViewModel
    @State private var selectedTab: AppTab = .stream
    @Environment(\.modelContext) private var modelContext
    @State private var appSettings: AppSettings?

    init(wearables: WearablesInterface, wearablesVM: WearablesViewModel) {
        self.wearables = wearables
        self.wearablesVM = wearablesVM
        self._streamViewModel = StateObject(wrappedValue: StreamSessionViewModel(
            wearables: wearables,
            falAPIKey: Config.falAPIKey
        ))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Keep all tabs alive
                StreamingTabContent(
                    viewModel: streamViewModel,
                    wearablesVM: wearablesVM,
                    appSettings: appSettings
                )
                    .opacity(selectedTab == .stream ? 1 : 0)
                    .allowsHitTesting(selectedTab == .stream)

                StickerLibraryView()
                    .opacity(selectedTab == .library ? 1 : 0)
                    .allowsHitTesting(selectedTab == .library)

                SettingsTabContent(viewModel: streamViewModel, appSettings: appSettings)
                    .opacity(selectedTab == .settings ? 1 : 0)
                    .allowsHitTesting(selectedTab == .settings)
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Picker("Tab", selection: $selectedTab) {
                        ForEach(AppTab.allCases, id: \.self) { tab in
                            Text(tab.rawValue).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    .fixedSize()
                }
            }
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .onAppear {
            setupDataAndSettings()
        }
        .alert("Error", isPresented: $streamViewModel.showError) {
            Button("OK") {
                streamViewModel.dismissError()
            }
        } message: {
            Text(streamViewModel.errorMessage)
        }
        .preferredColorScheme(selectedTab == .stream ? .light : nil)
    }

    private func setupDataAndSettings() {
        let dataManager = StickerDataManager(modelContext: modelContext)
        streamViewModel.segmentationManager.setDataManager(dataManager)

        // Load settings
        let settings = dataManager.getOrCreateSettings()
        self.appSettings = settings

        // Apply settings to segmentation manager
        let segManager = streamViewModel.segmentationManager
        segManager.pollingInterval = settings.pollingInterval
        segManager.currentPrompt = settings.currentPrompt
        segManager.autoSaveEnabled = settings.autoSaveStickers

        if settings.segmentationSource == "photoCapture" {
            segManager.source = .photoCapture
        } else {
            segManager.source = .videoFrame
        }

        print("[Settings] Loaded from TabContainer")
    }
}

struct StreamingTabContent: View {
    @ObservedObject var viewModel: StreamSessionViewModel
    @ObservedObject var wearablesVM: WearablesViewModel
    var appSettings: AppSettings?

    var body: some View {
        ZStack {
            if viewModel.isStreaming {
                StreamView(viewModel: viewModel, wearablesVM: wearablesVM, appSettings: appSettings)
            } else {
                NonStreamView(viewModel: viewModel, wearablesVM: wearablesVM)
            }
        }
    }
}

struct SettingsTabContent: View {
    @ObservedObject var viewModel: StreamSessionViewModel
    var appSettings: AppSettings?
    @State private var intervalText: String = ""

    private var segmentationManager: SegmentationManager {
        viewModel.segmentationManager
    }

    var body: some View {
        Form {
            Section(header: Text("Stream Quality")) {
                Picker("Resolution", selection: Binding(
                    get: { viewModel.streamQuality },
                    set: { viewModel.applyStreamSettings(quality: $0, fps: viewModel.streamFPS) }
                )) {
                    ForEach(StreamQuality.allCases, id: \.self) { quality in
                        Text(quality.rawValue).tag(quality)
                    }
                }

                Picker("Frame Rate", selection: Binding(
                    get: { viewModel.streamFPS },
                    set: { viewModel.applyStreamSettings(quality: viewModel.streamQuality, fps: $0) }
                )) {
                    ForEach(StreamFPS.allCases, id: \.self) { fps in
                        Text(fps.displayName).tag(fps)
                    }
                }

                if viewModel.isStreaming {
                    Text("Changes will restart the stream")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Section(header: Text("SAM3 Segmentation")) {
                Toggle("Enable SAM3", isOn: Binding(
                    get: { segmentationManager.isEnabled },
                    set: { newValue in
                        if newValue {
                            segmentationManager.start()
                        } else {
                            segmentationManager.stop()
                        }
                        appSettings?.segmentationEnabled = newValue
                    }
                ))

                Toggle("Auto-Save Stickers", isOn: Binding(
                    get: { segmentationManager.autoSaveEnabled },
                    set: { newValue in
                        segmentationManager.autoSaveEnabled = newValue
                        appSettings?.autoSaveStickers = newValue
                    }
                ))

                HStack {
                    Text("Status")
                    Spacer()
                    if segmentationManager.isProcessing {
                        HStack(spacing: 4) {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Processing")
                                .foregroundColor(.orange)
                        }
                    } else if segmentationManager.isEnabled {
                        Text("Ready")
                            .foregroundColor(.green)
                    } else {
                        Text("Disabled")
                            .foregroundColor(.secondary)
                    }
                }
            }

            Section(header: Text("Image Source")) {
                Picker("Source", selection: Binding(
                    get: { segmentationManager.source },
                    set: {
                        segmentationManager.source = $0
                        appSettings?.segmentationSource = $0.rawValue
                    }
                )) {
                    ForEach(SegmentationSource.allCases, id: \.self) { source in
                        Text(source.rawValue).tag(source)
                    }
                }

                if segmentationManager.source == .videoFrame {
                    Text("Uses video stream frames. Silent but lower quality.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("Captures photos from camera. Higher quality but makes shutter sound.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Section(header: Text("Polling Interval")) {
                HStack {
                    Text("Interval (seconds)")
                    Spacer()
                    TextField("1.0", text: $intervalText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                        .onSubmit {
                            if let interval = Double(intervalText) {
                                segmentationManager.setPollingInterval(interval)
                                appSettings?.pollingInterval = interval
                            }
                        }
                }

                Picker("Quick Select", selection: Binding(
                    get: { segmentationManager.pollingInterval },
                    set: {
                        segmentationManager.setPollingInterval($0)
                        appSettings?.pollingInterval = $0
                    }
                )) {
                    Text("0.5s").tag(0.5)
                    Text("1s").tag(1.0)
                    Text("2s").tag(2.0)
                    Text("5s").tag(5.0)
                }
                .pickerStyle(.segmented)
            }

            Section(header: Text("Segmentation Prompt")) {
                TextField("object", text: Binding(
                    get: { segmentationManager.currentPrompt },
                    set: {
                        segmentationManager.setPrompt($0)
                        appSettings?.currentPrompt = $0
                    }
                ))

                Text("Examples: object, person, car, hand, face")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if let error = segmentationManager.lastError {
                Section(header: Text("Last Error")) {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }

            if let result = segmentationManager.lastResult {
                Section(header: Text("Last Result")) {
                    if let score = result.score {
                        HStack {
                            Text("Confidence")
                            Spacer()
                            Text(String(format: "%.2f", score))
                        }
                    }
                    HStack {
                        Text("Timestamp")
                        Spacer()
                        Text(result.timestamp, style: .time)
                    }
                }
            }

            Section(header: Text("About")) {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("1.0.0")
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("API Status")
                    Spacer()
                    if Config.falAPIKey != nil {
                        Text("Connected")
                            .foregroundColor(.green)
                    } else {
                        Text("No API Key")
                            .foregroundColor(.red)
                    }
                }
            }
        }
        .onAppear {
            intervalText = String(format: "%.1f", segmentationManager.pollingInterval)
        }
    }
}
