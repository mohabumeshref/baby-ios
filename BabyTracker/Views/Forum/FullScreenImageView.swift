//
//  FullScreenImageView.swift
//  BabyTracker
//
//  Tap-to-enlarge for post images, comment images and avatars.
//

import SwiftUI

struct FullScreenImageView: View {
    let url: String
    @Environment(\.dismiss) private var dismiss

    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            AsyncImage(url: URL(string: url)) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                        .scaleEffect(scale)
                        .gesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    scale = min(max(lastScale * value, 1), 5)
                                }
                                .onEnded { _ in lastScale = scale }
                        )
                        .onTapGesture(count: 2) {
                            // Double-tap toggles between fit and 2x, the
                            // gesture people expect from Photos.
                            withAnimation(.easeOut(duration: 0.2)) {
                                scale = scale > 1 ? 1 : 2
                                lastScale = scale
                            }
                        }
                case .failure:
                    Image(systemName: "photo")
                        .font(.system(size: 40))
                        .foregroundStyle(.white.opacity(0.6))
                default:
                    ProgressView().tint(.white)
                }
            }
        }
        .overlay(alignment: .topTrailing) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.white, .black.opacity(0.4))
            }
            .buttonStyle(.plain)
            .padding()
        }
        // Swipe down to dismiss, matching the system photo viewer.
        .gesture(
            DragGesture().onEnded { value in
                if value.translation.height > 100, scale <= 1 { dismiss() }
            }
        )
    }
}
