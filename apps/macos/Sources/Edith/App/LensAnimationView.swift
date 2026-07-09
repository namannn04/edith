import SwiftUI

// MARK: - Entrance animation

struct LensEntranceView: View {
    @State private var lensOffset: CGFloat = 0
    @State private var fadeOut = false
    @State private var completed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let onComplete: () -> Void

    private let lensSize: CGFloat = 140

    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color(nsColor: .windowBackgroundColor))
                .ignoresSafeArea()

            if let icon = Brand.icon {
                Image(nsImage: icon)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 64, height: 64)
            }

            if !reduceMotion {
                LensHalf(side: .left, size: lensSize)
                    .offset(x: -lensOffset)

                LensHalf(side: .right, size: lensSize)
                    .offset(x: lensOffset)
            }
        }
        .opacity(reduceMotion && !completed ? 1 : (fadeOut ? 0 : 1))
        .allowsHitTesting(completed == false)
        .onAppear {
            if reduceMotion {
                completed = true
                onComplete()
                return
            }
            withAnimation(.interpolatingSpring(mass: 0.8, stiffness: 120, damping: 12, initialVelocity: 2)) {
                lensOffset = lensSize * 0.92
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                withAnimation(.easeOut(duration: 0.2)) {
                    fadeOut = true
                }
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                completed = true
                onComplete()
            }
        }
    }
}

// MARK: - Single lens half

private struct LensHalf: View {
    enum Side { case left, right }
    let side: Side
    let size: CGFloat

    @Environment(\.colorScheme) private var scheme

    private var halfWidth: CGFloat { (size / 2) + 0.5 }

    private var rimColor: Color {
        Color(nsColor: .controlAccentColor)
            .opacity(scheme == .dark ? 0.45 : 0.30)
    }

    private var gradient: LinearGradient {
        LinearGradient(
            colors: [
                .white.opacity(scheme == .dark ? 0.08 : 0.15),
                .white.opacity(scheme == .dark ? 0.02 : 0.05),
                .black.opacity(scheme == .dark ? 0.25 : 0.06),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var body: some View {
        Circle()
            .fill(gradient)
            .overlay(
                Circle()
                    .stroke(rimColor, lineWidth: 1.5)
            )
            .frame(width: size, height: size)
            .frame(width: halfWidth, height: size, alignment: side == .left ? .leading : .trailing)
            .clipped()
            .frame(width: halfWidth, height: size)
    }
}
