# Soothing player UI (mini pane + Music tab now-playing bar)

The music player chrome reads functional but cold. This restyles both
now-playing surfaces around three ideas the user picked: ambient artwork
glow, live visualizer bars, and softer motion. No external packages - the
one credible macOS candidate (DSWaveformImage) draws static waveforms,
which is not what was asked; everything here is native SwiftUI +
AVAudioPlayer metering.

## 1. Ambient glow backdrop

- Both surfaces draw the current track's artwork scaled up, blurred
  (~40-60pt radius), and dimmed (~35-50% dark overlay) behind their
  content, clipped to the surface's rounded shape.
- Tracks without embedded art fall back to the existing per-track hue
  gradient (same hue math as `TrackRow`'s placeholder tile).
- Track changes cross-fade the backdrop with `.easeInOut(duration: 0.6)`.
- Nothing playing: surfaces keep their current plain background.

## 2. Artwork thumbnail

- The mini pane gains a small rounded artwork thumbnail (~36pt) at its
  leading edge, loaded via the existing async `MusicPlayer.artwork(for:)`,
  cross-fading on change. The Music tab bar gets the same at ~40pt.
- Fallback: the hue-gradient tile with a music note, as in `TrackRow`.

## 3. Live visualizer bars

- `MusicPlayer` enables `isMeteringEnabled` on its `AVAudioPlayer` and
  exposes `meterLevel() -> Double` (0...1): calls `updateMeters()`, maps
  `averagePower(forChannel: 0)` from ~-50dB...0dB linearly, returns the
  resting value 0 when paused/stopped.
- The views render 5-6 slim capsules whose heights follow the level with
  per-bar variation (stable per-bar multipliers/phase so bars differ
  without randomness churn), animated `.easeOut(0.25)` - breathing, not
  jittering.
- Sampling rides the existing `TimelineView` ticks, bumped to ~0.1s on
  these surfaces; ticks only run while the surface is visible, so idle
  cost stays zero. Paused: bars settle to a low resting height (~15%).
- Replaces the `speaker.wave.2.fill` glyph as the "playing" indicator in
  the mini pane.

## 4. Softer feel

- Mini pane height 40pt -> ~58pt (adjust `MiniPanel`'s frame math);
  corner radius up a step; content padding up.
- Title/time/volume styling unchanged in function; title gains a subtle
  shadow over the glow for legibility; secondary text drops to
  `.secondary`/`.tertiary` over the backdrop.
- Artwork/title changes animate `.easeInOut(0.6)`; transport buttons keep
  the existing HoverButtonStyle.
- Presenter mode keeps blurring titles as today.

## Files

| File | Change |
|---|---|
| `Sources/Edith/Music/MusicPlayer.swift` | Enable metering; add `meterLevel()`; expose the artwork-or-hue fallback used by both surfaces if not already reusable. |
| `Sources/Edith/Music/MiniPlayer.swift` | Rework view: glow backdrop, thumbnail, bars, softer layout. |
| `Sources/Edith/Music/MiniPlayerPanel.swift` | Pane height + background hosting for the glow. |
| `Sources/Edith/Music/MusicView.swift` | Same treatment for `nowPlayingBar` (glow card, thumbnail, bars beside the title). Track list untouched. |

## Testing

Visual feature on AppKit surfaces - no new unit-test target material except
the meter mapping: one test for the dB->0...1 mapping edges (silence ->
0, -50dB -> 0, 0dB -> 1, paused -> 0) if the mapping is extracted as a
pure function (it should be: `LimitMath`-style static). Everything else is
the manual checklist: glow follows artwork, bars breathe on play / rest on
pause, cross-fades on track change, presenter blur intact, pane re-anchors
correctly at its new height.

## Out of scope

Track list rows, playback engine changes (AVAudioEngine/FFT), waveform
seek bars, external packages, the main panel's non-music tabs.
