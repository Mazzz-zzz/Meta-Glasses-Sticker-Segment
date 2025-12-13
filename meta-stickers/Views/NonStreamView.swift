//
//  NonStreamView.swift
//  meta-stickers
//

import SwiftUI

struct NonStreamView: View {
    @ObservedObject var viewModel: StreamSessionViewModel
    @ObservedObject var wearablesVM: WearablesViewModel
    @State private var showGettingStartedSheet = false

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "video.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 60, height: 60)
                    .foregroundColor(.white)

                Text("Ready to stream")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)

                Text("Stream live video from your Meta AI glasses")
                    .font(.system(size: 15))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Spacer()

                CustomButton(
                    title: "Start streaming",
                    style: .primary
                ) {
                    Task {
                        await viewModel.handleStartStreaming()
                    }
                }
                .padding(.horizontal, 24)

                Menu {
                    Button(role: .destructive) {
                        wearablesVM.disconnectGlasses()
                    } label: {
                        Label("Disconnect glasses", systemImage: "xmark.circle")
                    }

                    Button {
                        showGettingStartedSheet = true
                    } label: {
                        Label("Getting started", systemImage: "questionmark.circle")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                }
                .padding(.bottom, 16)
            }
        }
        .sheet(isPresented: $showGettingStartedSheet) {
            GettingStartedSheetView {
                showGettingStartedSheet = false
            }
        }
    }
}

struct GettingStartedSheetView: View {
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Text("Getting started")
                .font(.system(size: 24, weight: .bold))
                .padding(.top, 32)

            VStack(alignment: .leading, spacing: 16) {
                TipItemView(
                    icon: "1.circle.fill",
                    text: "Make sure your Meta AI glasses are connected via Bluetooth"
                )

                TipItemView(
                    icon: "2.circle.fill",
                    text: "Tap 'Start streaming' to begin capturing video"
                )

                TipItemView(
                    icon: "3.circle.fill",
                    text: "Use the camera button to capture photos while streaming"
                )
            }
            .padding(.horizontal, 24)

            Spacer()

            CustomButton(title: "Continue", style: .primary) {
                onDismiss()
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }
}

struct TipItemView: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(.appPrimary)
                .frame(width: 24)

            Text(text)
                .font(.system(size: 15))
                .foregroundColor(.primary)
        }
    }
}
