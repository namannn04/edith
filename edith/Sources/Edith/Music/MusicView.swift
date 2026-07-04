import SwiftUI

struct MusicView: View {
    @EnvironmentObject private var player: MusicPlayer
    @State private var dragFraction: Double?
    @AppStorage("presenterMode") private var presenter = false

    var body: some View {
        VStack(spacing: 8) {
            if player.tracks.isEmpty {
                Text("No mp3 files in \(Repo.musicDir.path)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.vertical, 24)
            } else {
                ScrollView {
                    LazyVStack(spacing: 1) {
                        ForEach(player.tracks) { track in
                            TrackRow(track: track)
                        }
                    }
                }
                .frame(maxHeight: 340)
                nowPlayingBar
            }
        }
        .onAppear { player.rescan() } // folder listing is cheap; keeps list in sync
    }

    private var nowPlayingBar: some View {
        VStack(spacing: 8) {
            if player.current != nil {
                // Ticks only while the panel is visible — zero cost when closed.
                TimelineView(.periodic(from: .now, by: 0.5)) { _ in
                    HStack(spacing: 8) {
                        Text(timeLabel(player.elapsed))
                            .frame(width: 34, alignment: .leading)
                        scrubber
                        Text(timeLabel(player.trackDuration))
                            .frame(width: 34, alignment: .trailing)
                    }
                    .font(.system(size: 9))
                    .monospacedDigit()
                    .foregroundStyle(.tertiary)
                }
            }
            HStack(spacing: 14) {
                Text(player.current?.title ?? "Not playing")
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
                    .foregroundStyle(player.current == nil ? .secondary : .primary)
                    .presenterBlur(presenter && player.current != nil)
                Spacer()
                Button { player.previous() } label: {
                    Image(systemName: "backward.fill")
                }
                Button { player.playPause() } label: {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 15))
                }
                Button { player.next() } label: {
                    Image(systemName: "forward.fill")
                }
                Slider(value: $player.volume, in: 0...1)
                    .controlSize(.mini)
                    .frame(width: 64)
            }
            .buttonStyle(.plain)
            .font(.system(size: 11))
        }
        .card()
    }

    /// Drag-to-seek progress capsule; while dragging it previews the grab point
    /// and only commits the seek on release.
    private var scrubber: some View {
        GeometryReader { geo in
            let fraction = dragFraction ?? player.progressNow()
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.08))
                Capsule()
                    .fill(Color.accentColor.opacity(0.85))
                    .frame(width: max(3, geo.size.width * fraction))
            }
            .contentShape(Rectangle().inset(by: -8)) // fat hit target for a 4pt bar
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { dragFraction = min(max($0.location.x / geo.size.width, 0), 1) }
                    .onEnded { value in
                        player.seek(to: min(max(value.location.x / geo.size.width, 0), 1))
                        dragFraction = nil
                    }
            )
        }
        .frame(height: 4)
    }

    private func timeLabel(_ t: TimeInterval) -> String {
        guard t.isFinite, t > 0 else { return "0:00" }
        let s = Int(t)
        return s >= 3600
            ? String(format: "%d:%02d:%02d", s / 3600, (s / 60) % 60, s % 60)
            : String(format: "%d:%02d", s / 60, s % 60)
    }
}

private struct TrackRow: View {
    @EnvironmentObject private var player: MusicPlayer
    let track: Track
    @State private var artwork: NSImage?
    @State private var duration: String?
    @State private var hovering = false
    @AppStorage("presenterMode") private var presenter = false

    private var isCurrent: Bool { player.current == track }

    var body: some View {
        Button {
            player.toggle(track)
        } label: {
            HStack(spacing: 8) {
                Group {
                    if let artwork {
                        Image(nsImage: artwork)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        // No embedded art → stable per-track tinted tile.
                        ZStack {
                            LinearGradient(
                                colors: [
                                    Color(hue: track.hue, saturation: 0.55, brightness: 0.45),
                                    Color(hue: track.hue, saturation: 0.6, brightness: 0.22),
                                ],
                                startPoint: .top, endPoint: .bottom
                            )
                            Image(systemName: "music.note")
                                .font(.system(size: 11))
                                .foregroundStyle(.white.opacity(0.8))
                        }
                    }
                }
                .frame(width: 28, height: 28)
                .clipShape(RoundedRectangle(cornerRadius: 6))

                Text(track.title)
                    .font(.system(size: 12))
                    .lineLimit(1)
                    .foregroundStyle(isCurrent ? Color.accentColor : .primary)
                    .presenterBlur(presenter)

                Spacer()

                if isCurrent {
                    Image(systemName: player.isPlaying ? "speaker.wave.2.fill" : "pause.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.accentColor)
                }

                if let duration {
                    Text(duration)
                        .font(.system(size: 10))
                        .monospacedDigit()
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            isCurrent ? Color.white.opacity(0.07) : hovering ? Color.white.opacity(0.04) : .clear,
            in: RoundedRectangle(cornerRadius: 6)
        )
        .onHover { hovering = $0 }
        .task {
            artwork = await player.artwork(for: track)
            duration = await player.durationLabel(for: track)
        }
    }
}
