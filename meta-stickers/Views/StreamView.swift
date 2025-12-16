//
//  StreamView.swift
//  meta-stickers
//

import SwiftUI

struct StreamView: View {
    @ObservedObject var viewModel: StreamSessionViewModel
    @ObservedObject var wearablesVM: WearablesViewModel
    var appSettings: AppSettings?
    @State private var showSegmentationSettings = false

    var body: some View {
        ZStack {
            Color(.secondarySystemBackground)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Compact video preview at the top
                VideoPreviewSection(viewModel: viewModel)

                // Divider
                Rectangle()
                    .fill(Color(.separator))
                    .frame(height: 1)

                // Live Sticker Feed
                LiveStickerFeedView(segmentationManager: viewModel.segmentationManager)

                // Controls at the bottom
                ControlsView(viewModel: viewModel, showSegmentationSettings: $showSegmentationSettings)
                    .padding(.vertical, 16)
                    .background(.regularMaterial)
            }
        }
        .sheet(isPresented: $viewModel.showPhotoPreview) {
            if let photo = viewModel.capturedPhoto {
                PhotoPreviewView(image: photo) {
                    viewModel.dismissPhotoPreview()
                }
            }
        }
        .sheet(isPresented: $showSegmentationSettings) {
            SegmentationSettingsView(
                segmentationManager: viewModel.segmentationManager,
                appSettings: appSettings
            )
        }
    }
}

// MARK: - Video Preview Section
struct VideoPreviewSection: View {
    @ObservedObject var viewModel: StreamSessionViewModel

    var body: some View {
        HStack {
            Spacer()
            ZStack {
                Color.black

                if let frame = viewModel.currentVideoFrame {
                    Image(uiImage: frame)
                        .resizable()
                        .scaledToFill()
                        .clipped()
                } else {
                    VStack(spacing: 4) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                        Text("Waiting...")
                            .foregroundColor(.white.opacity(0.7))
                            .font(.system(size: 10))
                    }
                }

                // Overlay indicators
                VStack {
                    HStack {
                        // Segmentation status indicator
                        if viewModel.segmentationManager.isEnabled {
                            HStack(spacing: 3) {
                                Circle()
                                    .fill(viewModel.segmentationManager.isProcessing ? Color.orange : Color.green)
                                    .frame(width: 5, height: 5)
                                Text("SAM3")
                                    .font(.system(size: 8, weight: .medium))
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color.black.opacity(0.5))
                            .cornerRadius(6)
                        }

                        Spacer()

                        if viewModel.activeTimeLimit.isTimeLimited {
                            Text(viewModel.remainingTime.formattedCountdown)
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Color.black.opacity(0.5))
                                .cornerRadius(6)
                        }
                    }
                    .padding(6)

                    Spacer()

                    // Show error if segmentation fails
                    if let error = viewModel.segmentationManager.lastError {
                        Text(error)
                            .font(.system(size: 8))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .padding(4)
                            .background(Color.red.opacity(0.8))
                            .cornerRadius(4)
                            .padding(4)
                    }
                }
            }
            .frame(width: 160, height: 90) // 16:9 aspect ratio, compact size
            .cornerRadius(8)
            Spacer()
        }
        .padding(.top, 8)
    }
}

// MARK: - Live Sticker Feed
struct LiveStickerFeedView: View {
    @ObservedObject var segmentationManager: SegmentationManager

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                HStack(spacing: 6) {
                    Circle()
                        .fill(segmentationManager.isEnabled ? Color.red : Color.gray)
                        .frame(width: 8, height: 8)
                    Text("Live Sticker Feed")
                        .font(.system(size: 14, weight: .semibold))
                }

                Spacer()

                if !segmentationManager.stickerHistory.isEmpty {
                    Button(action: {
                        segmentationManager.clearHistory()
                    }) {
                        Text("Clear")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            if segmentationManager.stickerHistory.isEmpty {
                // Empty state
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 36))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text(segmentationManager.isEnabled ? "Generating stickers..." : "Enable SAM3 to generate stickers")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                // Sticker grid
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(segmentationManager.stickerHistory) { sticker in
                            StickerItemView(sticker: sticker)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                }
            }
        }
    }
}

// MARK: - Sticker Item
struct StickerItemView: View {
    let sticker: SegmentationResult
    @State private var isAnimating = false

    var body: some View {
        ZStack {
            // Checkerboard background to show transparency
            CheckerboardBackground()
                .cornerRadius(12)

            if let image = sticker.maskImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding(6)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.separator), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
        .scaleEffect(isAnimating ? 1.0 : 0.5)
        .opacity(isAnimating ? 1.0 : 0.0)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                isAnimating = true
            }
        }
    }
}

// MARK: - Checkerboard Background
struct CheckerboardBackground: View {
    let squareSize: CGFloat = 8

    var body: some View {
        GeometryReader { geometry in
            let columns = Int(ceil(geometry.size.width / squareSize))
            let rows = Int(ceil(geometry.size.height / squareSize))

            Canvas { context, size in
                for row in 0..<rows {
                    for col in 0..<columns {
                        let isLight = (row + col) % 2 == 0
                        let rect = CGRect(
                            x: CGFloat(col) * squareSize,
                            y: CGFloat(row) * squareSize,
                            width: squareSize,
                            height: squareSize
                        )
                        context.fill(
                            Path(rect),
                            with: .color(isLight ? Color.white : Color.gray.opacity(0.3))
                        )
                    }
                }
            }
        }
    }
}

struct ControlsView: View {
    @ObservedObject var viewModel: StreamSessionViewModel
    @Binding var showSegmentationSettings: Bool

    var body: some View {
        HStack(spacing: 24) {
            CircleButton(icon: "xmark", text: "Stop") {
                viewModel.stopSession()
            }

            CircleButton(icon: "timer", text: viewModel.activeTimeLimit.displayText) {
                viewModel.cycleTimeLimit()
            }

            CircleButton(
                icon: viewModel.segmentationManager.isEnabled ? "wand.and.stars" : "wand.and.stars.inverse",
                text: "SAM3"
            ) {
                if viewModel.segmentationManager.isEnabled {
                    viewModel.segmentationManager.stop()
                } else {
                    viewModel.segmentationManager.start()
                }
            }
            .onLongPressGesture {
                showSegmentationSettings = true
            }

            CircleButton(icon: "camera.fill") {
                viewModel.capturePhoto()
            }
        }
    }
}

struct SegmentationSettingsView: View {
    @ObservedObject var segmentationManager: SegmentationManager
    var appSettings: AppSettings?
    @Environment(\.dismiss) private var dismiss
    @State private var intervalText: String = ""

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Segmentation")) {
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

                Section(header: Text("Storage")) {
                    Toggle("Auto-Save Stickers", isOn: $segmentationManager.autoSaveEnabled)
                        .onChange(of: segmentationManager.autoSaveEnabled) { _, newValue in
                            appSettings?.autoSaveStickers = newValue
                        }

                    Text("Automatically save generated stickers to your library")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Section(header: Text("Image Source")) {
                    Picker("Source", selection: $segmentationManager.source) {
                        ForEach(SegmentationSource.allCases, id: \.self) { source in
                            Text(source.rawValue).tag(source)
                        }
                    }
                    .pickerStyle(.automatic)
                    .onChange(of: segmentationManager.source) { _, newValue in
                        appSettings?.segmentationSource = newValue.rawValue
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

                    HStack {
                        Text("Quick Select")
                        Spacer()
                        Picker("", selection: Binding(
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
                }

                Section(header: Text("Prompt")) {
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
            }
            .navigationTitle("SAM3 Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        // Apply any pending interval change
                        if let interval = Double(intervalText), interval > 0 {
                            segmentationManager.setPollingInterval(interval)
                            appSettings?.pollingInterval = interval
                        }
                        dismiss()
                    }
                }
            }
            .onAppear {
                intervalText = String(format: "%.1f", segmentationManager.pollingInterval)
            }
        }
    }
}
