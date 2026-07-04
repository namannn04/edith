# Soothing Player UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ambient artwork glow, live metering visualizer bars, and softer motion on both now-playing surfaces (detached mini pane + Music tab bar).

**Architecture:** A new `PlayerGlow.swift` holds three reusable pieces — pure `MeterMath` (dB→level mapping, unit-tested), `VisualizerBars`, `ArtworkThumb`, `AmbientGlow` — fed by two tiny `MusicPlayer` additions (metering enable + `meterLevel()`). The two surfaces then compose them: `MiniPlayerDetached` hosts the glow as its background, `MusicView.nowPlayingBar` layers it under the existing card.

**Tech Stack:** SwiftUI + AVFoundation (AVAudioPlayer metering). **No new dependencies.** Swift tests via `./test.sh` (NOT bare `swift test` — CLT search-path gap).

**Spec:** `docs/superpowers/specs/2026-07-04-soothing-player-design.md`

## Global Constraints

- No external packages — everything native (spec rules out DSWaveformImage et al.).
- Meter mapping: `averagePower` dB clamped from −50dB…0dB → 0…1; paused/stopped ⇒ 0.
- Motion: track-change cross-fades `.easeInOut(duration: 0.6)`; bar animation `.easeOut(duration: 0.25)`; bars rest at 15% height when level is 0.
- Sampling: visualizer reads ride `TimelineView(.periodic(from: .now, by: 0.1))` — these only tick while the surface is visible, so idle cost stays zero.
- Mini pane height: `MiniPanel.height` 54 → 64 (the spec's "40pt" baseline was a misread; the pane is 54 today).
- Presenter mode must keep blurring titles.
- Commit messages: subject only, sentence case, no prefixes, NO AI attribution of any kind.
- Work directly on `main` (user-approved).
- Existing helpers you'll reuse (all in `Sources/Edith/App.swift:320-334`): `card()` = `padding(13)` + `.background(.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))`; `presenterBlur(_:)`; `HoverButtonStyle`.

---

### Task 1: MeterMath + shared glow components + MusicPlayer metering

**Files:**
- Create: `Sources/Edith/Music/PlayerGlow.swift`
- Modify: `Sources/Edith/Music/MusicPlayer.swift` (two additions)
- Test: `Tests/EdithTests/MeterMathTests.swift`

**Interfaces:**
- Consumes: `Track` (`.hue: Double`, `.id: URL`), `MusicPlayer.artwork(for:) async -> NSImage?`, `MusicPlayer.isPlaying`, private `player: AVAudioPlayer?`.
- Produces (Task 2 relies on these exact names):
  - `enum MeterMath { static func level(fromPower dB: Float) -> Double }`
  - `MusicPlayer.meterLevel() -> Double`
  - `struct VisualizerBars: View { let level: Double; let color: Color; var barCount: Int = 5 }`
  - `struct ArtworkThumb: View { let track: Track; @ObservedObject var player: MusicPlayer; var size: CGFloat = 36 }`
  - `struct AmbientGlow: View { let track: Track; @ObservedObject var player: MusicPlayer }`

- [ ] **Step 1: Write the failing test**

Create `Tests/EdithTests/MeterMathTests.swift`:

```swift
import Testing
@testable import Edith

@Suite struct MeterMathTests {
    @Test func mapsTheAudibleWindow() {
        #expect(MeterMath.level(fromPower: 0) == 1.0)        // full scale
        #expect(MeterMath.level(fromPower: -25) == 0.5)      // midpoint
        #expect(MeterMath.level(fromPower: -50) == 0.0)      // floor
    }

    @Test func clampsAndSurvivesGarbage() {
        #expect(MeterMath.level(fromPower: -160) == 0.0)     // silence, below floor
        #expect(MeterMath.level(fromPower: 10) == 1.0)       // over full scale
        #expect(MeterMath.level(fromPower: .nan) == 0.0)     // never NaN out
        #expect(MeterMath.level(fromPower: -.infinity) == 0.0)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `./test.sh --filter MeterMathTests 2>&1 | tail -3`
Expected: compile error, `cannot find 'MeterMath' in scope`.

- [ ] **Step 3: Create PlayerGlow.swift**

Create `Sources/Edith/Music/PlayerGlow.swift`:

```swift
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
```

- [ ] **Step 4: Add metering to MusicPlayer**

In `Sources/Edith/Music/MusicPlayer.swift`:

a) In `play(_ track:)`, directly after the `player = p` line, add:

```swift
        p.isMeteringEnabled = true
```

b) After the `progressNow()` function, add:

```swift
    /// 0...1 live output level for the visualizer bars; 0 when paused or
    /// stopped. Polled from TimelineViews that only tick while a player
    /// surface is visible - updateMeters() is cheap.
    func meterLevel() -> Double {
        guard isPlaying, let p = player else { return 0 }
        p.updateMeters()
        return MeterMath.level(fromPower: p.averagePower(forChannel: 0))
    }
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `./test.sh 2>&1 | tail -3`
Expected: all pass — 33 tests (31 existing + 2 new), `swift build 2>&1 | tail -1` clean.

- [ ] **Step 6: Commit**

```bash
git add Sources/Edith/Music/PlayerGlow.swift Sources/Edith/Music/MusicPlayer.swift Tests/EdithTests/MeterMathTests.swift
git commit -m "Player glow components: meter math, visualizer bars, artwork glow"
```

---

### Task 2: Apply to the mini pane and Music tab bar

**Files:**
- Modify: `Sources/Edith/Music/MiniPlayer.swift` (view rework)
- Modify: `Sources/Edith/Music/MiniPlayerPanel.swift` (height + glow background)
- Modify: `Sources/Edith/Music/MusicView.swift` (`nowPlayingBar` only)

**Interfaces:**
- Consumes: everything Task 1 produces (exact names in Task 1's Produces block), `timeLabel(_:)` (already private in both views — keep), `dismissPanel`-free surfaces (no behavior changes to controls).
- Produces: nothing downstream.

- [ ] **Step 1: Rework MiniPlayer.swift**

Replace the `body` of `struct MiniPlayer` (keep the struct shell, `timeLabel`, and properties; ADD nothing else) with:

```swift
    var body: some View {
        if let track = player.current {
            HStack(spacing: 12) {
                ArtworkThumb(track: track, player: player, size: 38)
                VStack(alignment: .leading, spacing: 3) {
                    Text(track.title)
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)
                        .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
                        .presenterBlur(presenter)
                    // Ticks only while the pane is visible.
                    TimelineView(.periodic(from: .now, by: 1)) { _ in
                        Text("\(timeLabel(player.elapsed)) / \(timeLabel(player.trackDuration))")
                            .font(.system(size: 10))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 8)
                TimelineView(.periodic(from: .now, by: 0.1)) { _ in
                    VisualizerBars(level: player.meterLevel(), color: theme.opacity(0.9))
                }
                Button {
                    player.playPause()
                } label: {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(theme)
                }
                .buttonStyle(HoverButtonStyle())
                Slider(value: $player.volume, in: 0...1)
                    .controlSize(.mini)
                    .tint(theme)
                    .frame(width: 60)
            }
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.easeInOut(duration: 0.6), value: track.id)
        }
    }
```

- [ ] **Step 2: Host the glow + new height in MiniPlayerPanel.swift**

a) Change `private let height: CGFloat = 54` to `private let height: CGFloat = 64`.

b) Replace `MiniPlayerDetached`'s `body`:

```swift
    var body: some View {
        MiniPlayer(player: player, theme: themeColor(themeName))
            .background {
                if let track = player.current {
                    AmbientGlow(track: track, player: player)
                        .animation(.easeInOut(duration: 0.6), value: track.id)
                }
            }
            .background(DetachedBackground())
    }
```

(`DetachedBackground` stays as the base dim layer under the glow.)

- [ ] **Step 3: Restyle nowPlayingBar in MusicView.swift**

Replace the `nowPlayingBar` computed property with:

```swift
    private var nowPlayingBar: some View {
        VStack(spacing: 10) {
            if player.current != nil {
                // Ticks only while the panel is visible - zero cost when closed.
                TimelineView(.periodic(from: .now, by: 0.5)) { _ in
                    HStack(spacing: 10) {
                        Text(timeLabel(player.elapsed))
                            .frame(width: 40, alignment: .leading)
                        scrubber
                        Text(timeLabel(player.trackDuration))
                            .frame(width: 40, alignment: .trailing)
                    }
                    .font(.system(size: 10))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                }
            }
            HStack(spacing: 12) {
                if let track = player.current {
                    ArtworkThumb(track: track, player: player, size: 40)
                }
                Text(player.current?.title ?? "Not playing")
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                    .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
                    .foregroundStyle(player.current == nil ? .secondary : .primary)
                    .presenterBlur(presenter && player.current != nil)
                if player.current != nil {
                    TimelineView(.periodic(from: .now, by: 0.1)) { _ in
                        VisualizerBars(level: player.meterLevel(), color: theme.opacity(0.9))
                    }
                }
                Spacer()
                Button { player.previous() } label: {
                    Image(systemName: "backward.fill")
                        .foregroundStyle(theme)
                }
                .buttonStyle(HoverButtonStyle())
                Button { player.playPause() } label: {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(theme)
                }
                .buttonStyle(HoverButtonStyle())
                Button { player.next() } label: {
                    Image(systemName: "forward.fill")
                        .foregroundStyle(theme)
                }
                .buttonStyle(HoverButtonStyle())
                Slider(value: $player.volume, in: 0...1)
                    .controlSize(.small)
                    .tint(theme)
                    .frame(width: 74)
            }
            .buttonStyle(.plain)
            .font(.system(size: 13))
        }
        .card()
        .background {
            if let track = player.current {
                AmbientGlow(track: track, player: player)
                    .clipShape(RoundedRectangle(cornerRadius: 12)) // matches card()'s shape
                    .animation(.easeInOut(duration: 0.6), value: track.id)
            }
        }
        .animation(.easeInOut(duration: 0.6), value: player.current)
    }
```

(The glow sits BEHIND `card()`'s 5%-tint background — SwiftUI stacks later `.background`s underneath earlier ones — so the card keeps a whisper of its material over the glow. The elapsed-time labels move from `.tertiary` to `.secondary` for legibility over the glow.)

- [ ] **Step 4: Build, test, install**

Run: `swift build 2>&1 | tail -1 && ./test.sh 2>&1 | tail -1 && ./build.sh --install 2>&1 | tail -1`
Expected: clean build, 33 tests pass, app relaunches from /Applications.

Manual checklist (human, can't be verified headless):
1. Play a track → mini pane shows artwork thumb + breathing bars over an ambient glow; pause → bars settle low, glow stays.
2. Next/previous → glow, thumb, and title cross-fade (~0.6s), no snapping.
3. Music tab now-playing card shows the same treatment; track list unchanged.
4. Presenter mode still blurs titles; light and dark mode both legible.
5. Mini pane sits at its new height without overlapping the main panel (re-anchor animation intact).

- [ ] **Step 5: Commit**

```bash
git add Sources/Edith/Music/MiniPlayer.swift Sources/Edith/Music/MiniPlayerPanel.swift Sources/Edith/Music/MusicView.swift
git commit -m "Soothing now-playing surfaces: ambient glow, visualizer bars, softer motion"
```

---

## Self-Review Notes

- **Spec coverage:** glow backdrop both surfaces (T1 AmbientGlow, T2 steps 2-3), hue fallback (T1), thumbnails 38/40pt (T2), metering + meterLevel + rest state (T1), 0.1s TimelineView sampling (T2), softer motion 0.6/0.25 + rest 15% (T1/T2), pane height (T2 step 2a), presenter blur (T2), meter mapping unit tests (T1). Spec's "~36pt" thumb became 38 in the mini pane for the 64pt pane — within spec intent.
- **Type consistency:** `MeterMath.level(fromPower:)` (T1 test, T1 impl, MusicPlayer caller); `VisualizerBars(level:color:)`, `ArtworkThumb(track:player:size:)`, `AmbientGlow(track:player:)` match between Produces and every T2 call site; `track.id` is `URL` (Equatable) — valid animation value.
- **No placeholders.**
