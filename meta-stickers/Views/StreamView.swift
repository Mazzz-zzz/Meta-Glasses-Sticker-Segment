//
//  StreamView.swift
//  meta-stickers
//

import SwiftUI

struct StreamView: View {
    @ObservedObject var viewModel: StreamSessionViewModel
    @ObservedObject var wearablesVM: WearablesViewModel
    @State private var showSegmentationSettings = false

    var body: some View {
        ZStack {
            Color(.secondarySystemBackground)
                .ignoresSafeArea()

            if let frame = viewModel.currentVideoFrame {
                ZStack {
                    Image(uiImage: frame)
                        .resizable()
                        .scaledToFit()

                    // Overlay segmentation mask if available
                    if viewModel.segmentationManager.isEnabled,
                       let maskImage = viewModel.segmentationManager.lastResult?.maskImage {
                        Image(uiImage: maskImage)
                            .resizable()
                            .scaledToFit()
                            .opacity(0.5)
                    }
                }
            } else {
                VStack(spacing: 16) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .primary))
                        .scaleEffect(1.5)

                    Text("Waiting for video stream...")
                        .foregroundColor(.secondary)
                        .font(.system(size: 14))
                }
            }

            VStack {
                // Top bar with time limit and segmentation status
                HStack {
                    // Segmentation status indicator
                    if viewModel.segmentationManager.isEnabled {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(viewModel.segmentationManager.isProcessing ? Color.orange : Color.green)
                                .frame(width: 8, height: 8)
                            Text("SAM3")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.primary)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.regularMaterial)
                        .cornerRadius(12)
                        .padding(.top, 16)
                        .padding(.leading, 16)
                    }

                    Spacer()

                    if viewModel.activeTimeLimit.isTimeLimited {
                        Text(viewModel.remainingTime.formattedCountdown)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(.regularMaterial)
                            .cornerRadius(16)
                            .padding(.top, 16)
                            .padding(.trailing, 16)
                    }
                }

                // Show error if segmentation fails
                if let error = viewModel.segmentationManager.lastError {
                    Text(error)
                        .font(.system(size: 12))
                        .foregroundColor(.red)
                        .padding(8)
                        .background(.regularMaterial)
                        .cornerRadius(8)
                        .padding(.horizontal)
                }

                Spacer()

                ControlsView(viewModel: viewModel, showSegmentationSettings: $showSegmentationSettings)
                    .padding(.bottom, 32)
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
            SegmentationSettingsView(segmentationManager: viewModel.segmentationManager)
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
                    Picker("Source", selection: $segmentationManager.source) {
                        ForEach(SegmentationSource.allCases, id: \.self) { source in
                            Text(source.rawValue).tag(source)
                        }
                    }
                    .pickerStyle(.automatic)

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

                    HStack {
                        Text("Quick Select")
                        Spacer()
                        Picker("", selection: Binding(
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
                }

                Section(header: Text("Prompt")) {
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
            }
            .navigationTitle("SAM3 Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        // Apply any pending interval change
                        if let interval = Double(intervalText), interval > 0 {
                            segmentationManager.setPollingInterval(interval)
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
