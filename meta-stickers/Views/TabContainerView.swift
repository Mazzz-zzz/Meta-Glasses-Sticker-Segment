//
//  TabContainerView.swift
//  meta-stickers
//

import MWDATCore
import SwiftUI

enum AppTab: String, CaseIterable {
    case stream = "Stream"
    case settings = "Settings"
}

struct TabContainerView: View {
    let wearables: WearablesInterface
    @ObservedObject var wearablesVM: WearablesViewModel
    @StateObject private var streamViewModel: StreamSessionViewModel
    @State private var selectedTab: AppTab = .stream

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
                // Keep both tabs alive
                StreamingTabContent(viewModel: streamViewModel, wearablesVM: wearablesVM)
                    .opacity(selectedTab == .stream ? 1 : 0)
                    .allowsHitTesting(selectedTab == .stream)

                SettingsTabContent(viewModel: streamViewModel)
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
        .alert("Error", isPresented: $streamViewModel.showError) {
            Button("OK") {
                streamViewModel.dismissError()
            }
        } message: {
            Text(streamViewModel.errorMessage)
        }
        .preferredColorScheme(selectedTab == .stream ? .light : nil)
    }
}

struct StreamingTabContent: View {
    @ObservedObject var viewModel: StreamSessionViewModel
    @ObservedObject var wearablesVM: WearablesViewModel

    var body: some View {
        ZStack {
            if viewModel.isStreaming {
                StreamView(viewModel: viewModel, wearablesVM: wearablesVM)
            } else {
                NonStreamView(viewModel: viewModel, wearablesVM: wearablesVM)
            }
        }
    }
}

struct SettingsTabContent: View {
    @ObservedObject var viewModel: StreamSessionViewModel
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
                    set: { segmentationManager.source = $0 }
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
                            }
                        }
                }

                Picker("Quick Select", selection: Binding(
                    get: { segmentationManager.pollingInterval },
                    set: { segmentationManager.setPollingInterval($0) }
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
                    set: { segmentationManager.setPrompt($0) }
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
