//
//  TabContainerView.swift
//  meta-stickers
//

import MWDATCore
import SwiftUI
import SwiftData

enum AppTab: String, CaseIterable {
    case stream = "Stream"
    case cutout = "Cutout"
    case style = "Style"
    case library = "Library"
    case settings = "Settings"

    var icon: String? {
        switch self {
        case .settings: return "gearshape"
        default: return nil
        }
    }
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

                CutoutTabContent(appSettings: appSettings, segmentationManager: streamViewModel.segmentationManager)
                    .opacity(selectedTab == .cutout ? 1 : 0)
                    .allowsHitTesting(selectedTab == .cutout)
                    .id("cutout-\(streamViewModel.segmentationManager.currentPrompt)")

                StyleTabContent(appSettings: appSettings, segmentationManager: streamViewModel.segmentationManager)
                    .opacity(selectedTab == .style ? 1 : 0)
                    .allowsHitTesting(selectedTab == .style)

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
                            if let icon = tab.icon {
                                Image(systemName: icon).tag(tab)
                            } else {
                                Text(tab.rawValue)
                                    .font(.caption)
                                    .tag(tab)
                            }
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

        // Apply style settings
        segManager.updateStyleSettings(from: settings)

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

// MARK: - Style Tab Content
struct StyleTabContent: View {
    var appSettings: AppSettings?
    var segmentationManager: SegmentationManager?
    @State private var selectedStyle: AppSettings.StickerStyle = .default

    var body: some View {
        VStack(spacing: 0) {
            // Fixed Preview at top
            StylePreviewSection(selectedStyle: selectedStyle)
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(.systemGroupedBackground))

            // Scrollable content below
            ScrollView {
                VStack(spacing: 16) {
                    // Style Presets
                    StylePresetsSection(selectedStyle: $selectedStyle, appSettings: appSettings, onStyleChange: updateSegmentationStyle)
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
        }
        .background(Color(.systemGroupedBackground))
        .onAppear {
            loadSettings()
        }
    }

    private func loadSettings() {
        guard let settings = appSettings else { return }
        selectedStyle = AppSettings.StickerStyle(rawValue: settings.stickerStyle) ?? .default
    }

    private func updateSegmentationStyle() {
        segmentationManager?.updateStyleSettings(from: appSettings)
    }
}

// MARK: - Style Preview Section
struct StylePreviewSection: View {
    let selectedStyle: AppSettings.StickerStyle

    var body: some View {
        VStack(spacing: 12) {
            Text("Preview")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            ZStack {
                // Checkerboard background
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.secondarySystemBackground))

                // Sample sticker preview
                ZStack {
                    Image(systemName: "star.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.yellow, .orange],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .padding(30)
                .modifier(StylePreviewModifier(style: selectedStyle))
            }
            .frame(height: 180)
            .clipShape(RoundedRectangle(cornerRadius: 16))

            Text(selectedStyle.displayName)
                .font(.subheadline.weight(.medium))
            Text(selectedStyle.description)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }
}

// MARK: - Style Preview Modifier
struct StylePreviewModifier: ViewModifier {
    let style: AppSettings.StickerStyle

    func body(content: Content) -> some View {
        switch style {
        case .default:
            content
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.white)
                        .shadow(color: .black.opacity(0.2), radius: 6, x: 0, y: 3)
                )
        case .outlined, .gpuOutline:
            content
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white, lineWidth: 4)
                        )
                        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                )
        case .cartoon:
            content
                .saturation(1.3)
                .contrast(1.2)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.black, lineWidth: 3)
                        )
                )
        case .minimal:
            content
                .saturation(0.9)
        case .glossy:
            content
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.white)
                        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [.white.opacity(0.4), .clear],
                                startPoint: .topLeading,
                                endPoint: .center
                            )
                        )
                        .padding(30)
                )
        case .vintage:
            content
                .saturation(0.7)
                .contrast(0.9)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(white: 0.95))
                        .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
                )
        }
    }
}

// MARK: - Style Presets Section
struct StylePresetsSection: View {
    @Binding var selectedStyle: AppSettings.StickerStyle
    var appSettings: AppSettings?
    var onStyleChange: (() -> Void)?

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        VStack(spacing: 12) {
            Text("Style Presets")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(AppSettings.StickerStyle.allCases, id: \.self) { style in
                    StylePresetButton(
                        style: style,
                        isSelected: selectedStyle == style
                    ) {
                        selectedStyle = style
                        appSettings?.stickerStyle = style.rawValue
                        onStyleChange?()
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }
}

struct StylePresetButton: View {
    let style: AppSettings.StickerStyle
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.tertiarySystemBackground))
                        .frame(height: 60)

                    Image(systemName: iconForStyle(style))
                        .font(.title2)
                        .foregroundColor(isSelected ? .accentColor : .secondary)
                }

                Text(style.displayName)
                    .font(.caption)
                    .foregroundColor(isSelected ? .accentColor : .primary)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
        )
    }

    private func iconForStyle(_ style: AppSettings.StickerStyle) -> String {
        switch style {
        case .default: return "sparkles"
        case .outlined: return "square.dashed"
        case .gpuOutline: return "cpu"
        case .cartoon: return "paintbrush.fill"
        case .minimal: return "minus.circle"
        case .glossy: return "light.max"
        case .vintage: return "camera.filters"
        }
    }
}

// MARK: - Cutout Tab Content
struct CutoutTabContent: View {
    var appSettings: AppSettings?
    @ObservedObject var segmentationManager: SegmentationManager
    @State private var newPrompt: String = ""

    private var prompts: [String] {
        appSettings?.segmentationPrompts ?? []
    }

    var body: some View {
        VStack(spacing: 0) {
            // Current selection header
            VStack(spacing: 4) {
                Text("DETECTING")
                    .font(.caption2.weight(.medium))
                    .foregroundColor(.secondary)
                    .tracking(1)

                Text(segmentationManager.currentPrompt.isEmpty ? "Nothing" : segmentationManager.currentPrompt)
                    .font(.title.weight(.semibold))
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .background(Color(.systemBackground))

            Divider()

            // Chips grid
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 10)], spacing: 10) {
                    ForEach(prompts, id: \.self) { prompt in
                        let isSelected = prompt == segmentationManager.currentPrompt
                        HStack(spacing: 0) {
                            Button {
                                selectPrompt(prompt)
                            } label: {
                                Text(prompt)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundColor(isSelected ? .white : .primary)
                                    .padding(.leading, 14)
                                    .padding(.vertical, 10)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.plain)

                            Button {
                                deletePrompt(prompt)
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.caption.weight(.semibold))
                                    .foregroundColor(isSelected ? .white.opacity(0.7) : .secondary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 10)
                            }
                            .buttonStyle(.plain)
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(isSelected ? Color.accentColor : Color(.secondarySystemBackground))
                        )
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))

            Divider()

            // Add new prompt
            HStack(spacing: 12) {
                TextField("New prompt...", text: $newPrompt)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(10)
                    .submitLabel(.done)
                    .onSubmit { addPrompt() }

                Button(action: addPrompt) {
                    Image(systemName: "plus")
                        .font(.body.weight(.semibold))
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(newPrompt.trimmingCharacters(in: .whitespaces).isEmpty ? Color.gray : Color.accentColor)
                        .cornerRadius(10)
                }
                .disabled(newPrompt.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding()
            .background(Color(.systemBackground))
        }
    }

    private func addPrompt() {
        let trimmed = newPrompt.trimmingCharacters(in: .whitespaces).lowercased()
        guard !trimmed.isEmpty else {
            newPrompt = ""
            return
        }
        guard !(appSettings?.segmentationPrompts.contains(trimmed) ?? false) else {
            newPrompt = ""
            return
        }

        appSettings?.segmentationPrompts.append(trimmed)
        newPrompt = ""
    }

    private func selectPrompt(_ prompt: String) {
        segmentationManager.setPrompt(prompt)
        appSettings?.currentPrompt = prompt
    }

    private func deletePrompt(_ prompt: String) {
        appSettings?.segmentationPrompts.removeAll { $0 == prompt }

        // If deleted the current prompt, select first available
        if segmentationManager.currentPrompt == prompt {
            if let first = appSettings?.segmentationPrompts.first {
                selectPrompt(first)
            } else {
                segmentationManager.setPrompt("")
                appSettings?.currentPrompt = ""
            }
        }
    }
}

