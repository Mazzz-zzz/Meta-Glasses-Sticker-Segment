//
//  StreamView.swift
//  meta-stickers
//

import SwiftUI

struct StreamView: View {
    @ObservedObject var viewModel: StreamSessionViewModel
    @ObservedObject var wearablesVM: WearablesViewModel

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            if let frame = viewModel.currentVideoFrame {
                Image(uiImage: frame)
                    .resizable()
                    .scaledToFit()
            } else {
                VStack(spacing: 16) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)

                    Text("Waiting for video stream...")
                        .foregroundColor(.white)
                        .font(.system(size: 14))
                }
            }

            VStack {
                if viewModel.activeTimeLimit.isTimeLimited {
                    HStack {
                        Spacer()
                        Text(viewModel.remainingTime.formattedCountdown)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(16)
                            .padding(.top, 16)
                            .padding(.trailing, 16)
                    }
                }

                Spacer()

                ControlsView(viewModel: viewModel)
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
        .onDisappear {
            viewModel.stopSession()
        }
    }
}

struct ControlsView: View {
    @ObservedObject var viewModel: StreamSessionViewModel

    var body: some View {
        HStack(spacing: 24) {
            CircleButton(icon: "xmark", text: "Stop") {
                viewModel.stopSession()
            }

            CircleButton(icon: "timer", text: viewModel.activeTimeLimit.displayText) {
                viewModel.cycleTimeLimit()
            }

            CircleButton(icon: "camera.fill") {
                viewModel.capturePhoto()
            }
        }
    }
}
