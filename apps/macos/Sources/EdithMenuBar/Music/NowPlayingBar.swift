import EdithKit
import SwiftUI

struct NowPlayingBar: View {
    @ObservedObject var player: MusicPlayer
    let theme: Color
    @State private var dragFraction: Double?
    @State private var tick = Date()
    @StateObject private var presenterState = PresenterState.shared
    @AppStorage("presenterBlurMusic", store: SharedDefaults.store) private var presenterBlurMusic =
        true

    private var blurMusic: Bool { presenterState.active && presenterBlurMusic }

    var body: some View {
        if let track = player.current {
            VStack(spacing: 8) {
                HStack(spacing: 12) {
                    ArtworkThumb(track: track, player: player, size: 38)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(track.title)
                            .font(.system(size: 12, weight: .semibold))
                            .lineLimit(1)
                            .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
                            .presenterBlur(blurMusic)
                        TimelineView(.periodic(from: tick, by: 1)) { _ in
                            Text(
                                "\(timeLabel(player.elapsed)) / \(timeLabel(player.trackDuration))"
                            )
                            .font(.system(size: 10))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                        }
                    }
                    Spacer(minLength: 8)
                    if player.isPlaying {
                        TimelineView(.periodic(from: tick, by: 0.2)) { _ in
                            VisualizerBars(level: player.meterLevel(), color: theme.opacity(0.9))
                        }
                    } else {
                        VisualizerBars(level: 0, color: theme.opacity(0.9))
                    }
                    Button {
                        player.previous()
                    } label: {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(theme)
                    }
                    .buttonStyle(HoverButtonStyle())
                    Button {
                        player.playPause()
                    } label: {
                        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 15))
                            .foregroundStyle(theme)
                    }
                    .buttonStyle(HoverButtonStyle())
                    Button {
                        player.next()
                    } label: {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(theme)
                    }
                    .buttonStyle(HoverButtonStyle())
                    Button {
                        player.isLooping.toggle()
                    } label: {
                        Image(systemName: "repeat")
                            .font(.system(size: 12))
                            .foregroundStyle(player.isLooping ? theme : .secondary)
                    }
                    .buttonStyle(HoverButtonStyle())
                    .help(player.isLooping ? "Looping current song" : "Shuffle next")
                    Slider(value: $player.volume, in: 0...1)
                        .controlSize(.mini)
                        .tint(theme)
                        .frame(width: 60)
                        .pointerCursor()
                }
                scrubber
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
            .background {
                AmbientGlow(track: track, player: player)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .animation(.easeInOut(duration: 0.6), value: track.id)
            }
            .animation(.easeInOut(duration: 0.6), value: track.id)
        }
    }

    private var scrubber: some View {
        GeometryReader { geo in
            let knob: CGFloat = 10
            ZStack(alignment: .leading) {
                Capsule().fill(.primary.opacity(0.1))
                TimelineView(.periodic(from: tick, by: 0.25)) { _ in
                    let fraction = dragFraction ?? player.progressNow()
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(theme.opacity(0.85))
                            .frame(width: max(3, geo.size.width * fraction))
                        Circle()
                            .fill(theme)
                            .frame(width: knob, height: knob)
                            .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
                            .offset(
                                x: min(
                                    max(geo.size.width * fraction - knob / 2, 0),
                                    geo.size.width - knob))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .contentShape(Rectangle().inset(by: -8))
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { dragFraction = min(max($0.location.x / geo.size.width, 0), 1) }
                    .onEnded { value in
                        player.seek(to: min(max(value.location.x / geo.size.width, 0), 1))
                        dragFraction = nil
                    }
            )
        }
        .frame(height: 5)
        .pointerCursor()
    }

    private func timeLabel(_ t: TimeInterval) -> String {
        guard t.isFinite, t > 0 else { return "0:00" }
        let s = Int(t)
        return s >= 3600
            ? String(format: "%d:%02d:%02d", s / 3600, (s / 60) % 60, s % 60)
            : String(format: "%d:%02d", s / 60, s % 60)
    }
}
