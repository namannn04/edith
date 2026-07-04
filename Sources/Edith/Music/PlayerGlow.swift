import AppKit
import SwiftUI

/// Pure mapping from AVAudioPlayer meter dB to a 0...1 display level.
/// -50dB floor keeps quiet passages resting near zero instead of dancing.
enum MeterMath {
    static func level(fromPower dB: Float) -> Double {
        guard dB.isFinite else { return 0 }
        return Double(min(max((dB + 50) / 50, 0), 1))
    }
}

/// Slim capsules that breathe with the music. Feed `level` from a
/// TimelineView tick; stable per-bar weights keep the bars distinct
/// without randomness churn. Rests at 15% height when level is 0.
struct VisualizerBars: View {
    let level: Double
    let color: Color
    var barCount: Int = 5

    // per-bar personality: mids taller, edges shyer
    private static let weights: [Double] = [0.55, 0.85, 1.0, 0.75, 0.6, 0.9, 0.5]
    private let maxHeight: CGFloat = 18

    var body: some View {
        HStack(spacing: 2.5) {
            ForEach(0..<barCount, id: \.self) { i in
                Capsule()
                    .fill(color)
                    .frame(width: 3, height: height(i))
            }
        }
        .frame(height: maxHeight, alignment: .center)
        .animation(.easeOut(duration: 0.25), value: level)
    }

    private func height(_ i: Int) -> CGFloat {
        let weight = Self.weights[i % Self.weights.count]
        return maxHeight * CGFloat(max(0.15, level * weight))
    }
}

/// Rounded artwork tile; tracks without embedded art get their stable
/// per-track hue gradient (same math as the track list's placeholder).
struct ArtworkThumb: View {
    let track: Track
    @ObservedObject var player: MusicPlayer
    var size: CGFloat = 36
    @State private var artwork: NSImage?

    var body: some View {
        Group {
            if let artwork {
                Image(nsImage: artwork)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    LinearGradient(
                        colors: [
                            Color(hue: track.hue, saturation: 0.55, brightness: 0.45),
                            Color(hue: track.hue, saturation: 0.6, brightness: 0.22),
                        ],
                        startPoint: .top, endPoint: .bottom)
                    Image(systemName: "music.note")
                        .font(.system(size: size * 0.36))
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.22))
        .task(id: track.id) { artwork = await player.artwork(for: track) }
    }
}

/// The current track's artwork scaled to fill, heavily blurred and dimmed -
/// the ambient backdrop behind a now-playing surface. Hue-gradient fallback
/// when there's no art. Parents animate track changes (.easeInOut 0.6).
struct AmbientGlow: View {
    let track: Track
    @ObservedObject var player: MusicPlayer
    @Environment(\.colorScheme) private var scheme
    @State private var artwork: NSImage?

    var body: some View {
        GeometryReader { geo in
            Group {
                if let artwork {
                    Image(nsImage: artwork)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geo.size.width, height: geo.size.height)
                } else {
                    LinearGradient(
                        colors: [
                            Color(hue: track.hue, saturation: 0.5, brightness: 0.5),
                            Color(hue: track.hue, saturation: 0.65, brightness: 0.25),
                        ],
                        startPoint: .topLeading, endPoint: .bottomTrailing)
                }
            }
            .blur(radius: 50)
            .overlay((scheme == .dark ? Color.black : Color.white).opacity(0.45))
            .clipped()
        }
        .task(id: track.id) { artwork = await player.artwork(for: track) }
        .allowsHitTesting(false)
    }
}
