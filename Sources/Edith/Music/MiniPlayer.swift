import SwiftUI

/// Compact now-playing bar shown outside the Music tab while audio plays:
/// small title, elapsed/total, play-pause, volume. The full player owns the
/// Music tab, so this only exists on the other screens.
struct MiniPlayer: View {
    @ObservedObject var player: MusicPlayer
    let theme: Color
    @AppStorage("presenterMode") private var presenter = false

    var body: some View {
        if let track = player.current {
            HStack(spacing: 12) {
                Image(systemName: player.isPlaying ? "speaker.wave.2.fill" : "pause.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(theme)
                Text(track.title)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                    .presenterBlur(presenter)
                Spacer(minLength: 8)
                // Ticks only while the panel is visible.
                TimelineView(.periodic(from: .now, by: 1)) { _ in
                    Text("\(timeLabel(player.elapsed)) / \(timeLabel(player.trackDuration))")
                        .font(.system(size: 10))
                        .monospacedDigit()
                        .foregroundStyle(.tertiary)
                }
                Button {
                    player.playPause()
                } label: {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(theme)
                }
                .buttonStyle(HoverButtonStyle())
                Slider(value: $player.volume, in: 0...1)
                    .controlSize(.mini)
                    .tint(theme)
                    .frame(width: 60)
            }
            .card()
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private func timeLabel(_ t: TimeInterval) -> String {
        guard t.isFinite, t > 0 else { return "0:00" }
        let s = Int(t)
        return s >= 3600
            ? String(format: "%d:%02d:%02d", s / 3600, (s / 60) % 60, s % 60)
            : String(format: "%d:%02d", s / 60, s % 60)
    }
}
