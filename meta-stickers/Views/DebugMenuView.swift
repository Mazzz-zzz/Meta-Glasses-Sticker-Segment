//
//  DebugMenuView.swift
//  meta-stickers
//

#if DEBUG
import MWDATMockDevice
import SwiftUI

struct DebugMenuView: View {
    @ObservedObject var debugMenuViewModel: DebugMenuViewModel

    var body: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Button {
                    debugMenuViewModel.toggleDebugMenu()
                } label: {
                    Image(systemName: "ladybug.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                        .frame(width: 50, height: 50)
                        .background(Color.orange)
                        .clipShape(Circle())
                        .shadow(radius: 4)
                }
                .padding(.trailing, 16)
                .padding(.bottom, 100)
            }
        }
    }
}

struct MockDeviceDebugView: View {
    let mockDeviceKit: any MockDeviceKitInterface

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Mock Device Kit")
                    .font(.headline)

                Text("Use this to simulate a Meta AI glasses connection for testing.")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Text("Connect a real device or use the Meta AI app to pair with your glasses.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Spacer()
            }
            .padding()
            .navigationTitle("Debug Menu")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
#endif
