//
//  PhotoPreviewView.swift
//  meta-stickers
//

import SwiftUI

struct PhotoPreviewView: View {
    let image: UIImage
    let onDismiss: () -> Void

    @State private var offset: CGSize = .zero
    @State private var showShareSheet = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.9)
                .ignoresSafeArea()
                .onTapGesture {
                    onDismiss()
                }

            VStack {
                HStack {
                    Button {
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                    }
                    Spacer()

                    Button {
                        showShareSheet = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                    }
                }
                .padding(.horizontal, 16)

                Spacer()

                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .cornerRadius(12)
                    .shadow(radius: 10)
                    .padding(.horizontal, 24)
                    .offset(y: offset.height)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                offset = value.translation
                            }
                            .onEnded { value in
                                if abs(value.translation.height) > 100 {
                                    onDismiss()
                                } else {
                                    withAnimation(.spring()) {
                                        offset = .zero
                                    }
                                }
                            }
                    )

                Spacer()

                Text("Swipe down to dismiss")
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
                    .padding(.bottom, 32)
            }
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(image: image)
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let image: UIImage

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: [image],
            applicationActivities: nil
        )
        controller.excludedActivityTypes = [
            .assignToContact,
            .addToReadingList
        ]
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
