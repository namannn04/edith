import EdithKit
import SwiftUI

struct ExtensionPreview: View {
    let entry: ExtensionRegistryEntry
    let dark: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion)) { context in
            preview(phase: reduceMotion ? 1.1 : context.date.timeIntervalSinceReferenceDate)
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func preview(phase: Double) -> some View {
        switch entry.id {
        case "usage": usagePreview(phase: phase)
        case "system": systemPreview(phase: phase)
        case "notchShelf": notchPreview(phase: phase)
        case "clipboard": clipboardPreview(phase: phase)
        case "music": musicPreview
        default: staticPreview
        }
    }

    private func usagePreview(phase: Double) -> some View {
        let fill = CGFloat(0.48 + sin(phase * 1.7) * 0.2)
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("SESSION")
                    .font(DashSkin.mono(7, weight: .semibold))
                Spacer()
                Text("\(Int(fill * 100))%")
                    .font(DashSkin.mono(8, weight: .medium))
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(DashSkin.lineStrong(dark))
                    Capsule()
                        .fill(brandAccent)
                        .frame(width: max(10, proxy.size.width * fill))
                }
            }
            .frame(height: 7)
        }
        .foregroundStyle(DashSkin.inkSoft(dark))
        .padding(.horizontal, 15)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func systemPreview(phase: Double) -> some View {
        HStack(spacing: 7) {
            ForEach(Array(["⌘", "⌥", "E", "⏎"].enumerated()), id: \.offset) { index, key in
                let press = CGFloat(max(0, sin(phase * 2.2 - Double(index) * 0.7)))
                Text(key)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(DashSkin.ink(dark))
                    .frame(width: 28, height: 25)
                    .background(DashSkin.paper2(dark), in: RoundedRectangle(cornerRadius: 6))
                    .overlay {
                        RoundedRectangle(cornerRadius: 6).strokeBorder(DashSkin.lineStrong(dark))
                    }
                    .shadow(color: .black.opacity(0.1), radius: 0, y: 2 - press * 2)
                    .offset(y: press * 2)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func notchPreview(phase: Double) -> some View {
        let pulse = CGFloat((sin(phase * 1.8) + 1) / 2)
        return VStack(spacing: 0) {
            BottomRoundedRectangle(radius: 12)
                .fill(Color.black)
                .frame(width: 80 + pulse * 44, height: 20 + pulse * 13)
            Spacer(minLength: 0)
            HStack(spacing: 5) {
                Circle().fill(brandAccent).frame(width: 5, height: 5)
                Capsule().fill(DashSkin.lineStrong(dark)).frame(width: 38, height: 4)
            }
        }
        .padding(.top, 1)
        .padding(.bottom, 7)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func clipboardPreview(phase: Double) -> some View {
        VStack(spacing: 4) {
            ForEach(0..<3) { index in
                let progress = (sin(phase * 1.8 - Double(index) * 0.8) + 1) / 2
                HStack(spacing: 7) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(brandAccent.opacity(0.55 + Double(index) * 0.12))
                        .frame(width: 8, height: 8)
                    Capsule()
                        .fill(DashSkin.inkFaint(dark).opacity(0.48))
                        .frame(width: CGFloat(44 + index * 14), height: 4)
                    Spacer(minLength: 0)
                }
                .offset(x: -8 + progress * 8)
                .opacity(0.5 + progress * 0.5)
            }
        }
        .padding(.horizontal, 25)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var musicPreview: some View {
        HStack(spacing: 13) {
            PlaybackWave(
                playing: !reduceMotion, color: brandAccent, barCount: 7, maxHeight: 28)
            VStack(alignment: .leading, spacing: 5) {
                Capsule().fill(DashSkin.inkSoft(dark).opacity(0.65)).frame(width: 62, height: 5)
                Capsule().fill(DashSkin.inkFaint(dark).opacity(0.42)).frame(width: 43, height: 4)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var staticPreview: some View {
        Image(systemName: entry.symbolName)
            .font(.system(size: 22, weight: .medium))
            .foregroundStyle(brandAccent)
            .frame(width: 42, height: 42)
            .background(brandAccent.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct BottomRoundedRectangle: Shape {
    let radius: CGFloat

    func path(in rect: CGRect) -> Path {
        let cornerRadius = min(radius, min(rect.width / 2, rect.height))
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - cornerRadius))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - cornerRadius, y: rect.maxY),
            control: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + cornerRadius, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.maxY - cornerRadius),
            control: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
