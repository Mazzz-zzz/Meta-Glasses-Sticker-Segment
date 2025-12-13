//
//  HomeScreenView.swift
//  meta-stickers
//

import MWDATCore
import SwiftUI

struct HomeScreenView: View {
    @ObservedObject var viewModel: WearablesViewModel

    var body: some View {
        ZStack {
            Color.white
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "camera.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
                    .foregroundColor(.appPrimary)

                Text("Meta Stickers")
                    .font(.system(size: 28, weight: .bold))

                VStack(alignment: .leading, spacing: 16) {
                    HomeTipItemView(
                        icon: "video.fill",
                        title: "Video Capture",
                        description: "Stream live video from your Meta AI glasses"
                    )

                    HomeTipItemView(
                        icon: "headphones",
                        title: "Open-Ear Audio",
                        description: "Hear ambient sound while streaming"
                    )

                    HomeTipItemView(
                        icon: "figure.walk",
                        title: "Enjoy On-the-Go",
                        description: "Capture moments hands-free"
                    )
                }
                .padding(.horizontal, 24)

                Spacer()

                Text("You'll be redirected to the Meta AI app to confirm your connection.")
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                CustomButton(
                    title: "Connect my glasses",
                    style: .primary,
                    isDisabled: viewModel.registrationState == .registering
                ) {
                    viewModel.connectGlasses()
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
    }
}

struct HomeTipItemView: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .resizable()
                .scaledToFit()
                .frame(width: 24, height: 24)
                .foregroundColor(.black)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.black)

                Text(description)
                    .font(.system(size: 15))
                    .foregroundColor(.gray)
            }
        }
    }
}
