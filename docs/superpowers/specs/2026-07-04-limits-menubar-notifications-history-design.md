# Limits in the menu bar, notifications, and limits history

Three additions to Edith's Usage feature, all fed by the existing 5-minute
OAuth limits poll in `UsageStore`:

1. A second menu bar item showing session + weekly percentages as numbers.
2. Rate-limit notifications ported from TokenEater's full strategy
   (thresholds, Smart Color risk model, pacing zones, reset reminders,
   recovery, token-expired).
3. Limits history recorded on every poll - a compact 24h chart in the panel,
   full curves with range selection in the HTML dashboard.

TokenEater's source is vendored at `local/extras/TokenEater/` and is the
reference implementation; its pure logic (SmartColor, PacingCalculator,
notification evaluation) ports nearly verbatim, minus subsystems Edith has no
data for.

## 1. Menu bar numbers

- A plain AppKit `NSStatusItem` next to the existing MenuBarExtra glasses
  icon. Its button title is an attributed string like `⏱ 42  W 67` - session
  first, weekly second, each number tinted independently.
- Colors: with Smart Color enabled (default), the tint comes from the
  continuous risk score via the ported `nsColorForRisk` (green -> orange ->
  red HSB interpolation, anchors fixed at system green/orange/red - no theme
  system). With Smart Color off, flat threshold colors: green below warning,
  orange at/above warning, red at/above critical.
- Click action: `togglePanel()` - opens/closes the same Edith panel.
- Settings toggle "Show limits in menu bar" (default on). Off destroys the
  status item entirely.
- Menu bar color setting (user addition): Auto (default, risk tints as
  above) | White | Black. A fixed choice colors every part of the widget -
  labels, numbers, dashes - uniformly.
- While limits are unavailable (no token, offline, 429 backoff): dimmed `–`
  placeholders. The item never disappears on its own; only the setting
  removes it.
- Integration fix: `clickStatusItem()` and `centerPanelUnderIcon()` in
  `App.swift` currently grab the first `StatusBarWindow`-class window. With
  a second status item that's ambiguous. Both lookups change to identify the
  MenuBarExtra's own window (exclude the new item's button window by
  comparing against our `NSStatusItem.button`).

## 2. Notifications - TokenEater strategy port

New `Sources/Edith/Usage/LimitNotifier.swift` plus pure helpers, called from
`UsageStore` after every successful limits fetch. Surfaces: **session
(five-hour)** and **weekly (seven-day)** only.

### Ported subsystems

- **Threshold escalation** - per surface, compute a green/orange/red level;
  persist the last level in UserDefaults; on upward change fire one
  notification, on downward change to green fire an optional recovery
  notification. Edge-triggered, so each state is announced once.
- **Smart Color risk model** - `SmartColor.swift` pure functions copied from
  TokenEater: smoothstep, confidence weighting, absolute/projection/pacing
  risk components, `combinedRisk`, `zoneForRisk` with hysteresis,
  `legacyLevel`. Uses the **balanced** profile's parameters as constants -
  no profile picker. When Smart Color is on (default), the notification
  level comes from risk; when off, from raw thresholds. Pace-driven
  escalations on the weekly surface use "ahead of pace" wording instead of
  "almost capped" (TokenEater issue #187 behavior).
- **Pacing zones** - `PacingCalculator` core: elapsed fraction of the window
  -> expected usage -> delta -> chill/onTrack/warning/hot with the margin
  setting (default 10pp, warning at margin..2x, hot beyond 2x). Notify on
  entry to warning/hot (each gated by its own toggle); recovery to
  chill/onTrack is silent. Active days/hours scheduling is NOT ported -
  full-window pacing only.
- **Reset reminders** - scheduled `UNCalendarNotificationTrigger` X minutes
  before the session and/or weekly reset; rescheduled on every poll (cancel
  then re-add) so moving reset times don't pile up duplicates.
- **Token expired** - fired from `UsageStore`'s existing unauthorized path,
  deduped to once per hour via a persisted timestamp.
- **Test notification** button in settings.
- **Foreground banners** - a `UNUserNotificationCenterDelegate` that allows
  banner + sound while the app is frontmost.

### Not ported (no Edith data source)

Sonnet/Design surfaces, extra credits, vendor status/outage alerts,
localization (English strings hardcoded, copy adapted from TokenEater's
`en.lproj`), pacing schedules, theme system, smart color profile picker.

### Settings (new "Notifications" group in Edith's Settings tab)

| Setting | Default |
|---|---|
| Master switch | off until the user enables (triggers permission prompt) |
| Track session / track weekly | on / on |
| Recovery notifications | on |
| Pacing warning / hot alerts | on / on |
| Reset reminder session + offset | off, 30 min |
| Reset reminder weekly + offset | off, 120 min |
| Token expired alert | on |
| Smart Color | on |
| Pacing margin | 10pp |
| Warning / critical thresholds | 60% / 85% (TokenEater defaults) |
| Menu bar color | auto (white / black optional) |
| Test notification button | - |

Thresholds and Smart Color also drive the menu bar number colors so all
user-visible signals agree.

## 3. History recording

- After each successful poll, `UsageStore` appends one line to
  `dashboard/data/limits-history.jsonl` (directory is already gitignored):

  ```json
  {"ts":"2026-07-04T10:05:00Z","s":42.1,"w":67.3,"sr":"2026-07-04T13:00:00Z","wr":"2026-07-09T00:00:00Z"}
  ```

  `s`/`w` = session/weekly utilization percent, `sr`/`wr` = reset times
  (nullable).
- Skip the append when all four values equal the previous row's - an idle
  Mac writes nothing overnight; flat segments are reconstructed client-side
  by carrying the last value forward to the next point.
- No pruning. Worst case is a few MB per year; revisit if it ever matters.

## 4. Panel: compact history chart

- In the Usage tab, below the limit rings: a "last 24h" chart, two lines
  (session + weekly) drawn with Swift Charts (macOS 14 target - available).
- Dashed horizontal rules at the warning/critical thresholds.
- Data: tail of the JSONL re-read when the panel opens (mtime-gated like
  usage.json); carry-forward fill between sparse points.
- Hidden (with a one-line hint) until the history file has data.

## 5. Dashboard: full limits history

- `render.mjs` reads `data/limits-history.jsonl` and inlines it into
  `dashboard.html` as a second `<script id="limits-data">` JSON block
  (same pattern as the existing usage-data block). Rows older than 7 days
  are downsampled to hourly maxima to bound the payload.
- New "Limits" section in the dashboard: session + weekly curves on a
  time axis, range pills (24h / 7d / 30d / all), dashed threshold rules,
  and vertical markers where a window reset (reset time changed between
  consecutive rows). Built with the existing hand-rolled canvas/JS chart
  patterns in `js/charts.js` - no new chart library.
- Data freshness = last `cc-update` run, same as everything else there.

## Data flow

```
UsageStore poll (5 min, wake, manual)
  ├─ apply() -> published session/week    (existing rings)
  ├─ LimitsStatusItem.update()            (menu bar numbers)
  ├─ LimitNotifier.evaluate()             (notifications + reminders)
  └─ HistoryLog.append()                  (limits-history.jsonl)
                                             ├─ panel 24h chart (Swift Charts)
                                             └─ render.mjs -> dashboard Limits section
```

## Error handling

- No token / offline / 429: menu bar shows dimmed placeholders, notifier
  and history writer are simply not called (no data, no state change).
  Token-expired notification fires from the 401 re-fetch failure path.
- Notification permission denied: settings section shows a "notifications
  disabled in System Settings" hint; evaluation still runs (state tracking
  stays correct) but `UNUserNotificationCenter.add` calls are no-ops.
- Malformed/missing JSONL lines: skipped on read (both Swift and JS
  parsers); the writer only ever appends complete lines.

## Testing

- **Swift**: SmartColor risk/zone math, pacing delta/zone derivation, and
  the notifier's edge-trigger state machine live as pure functions. A small
  test executable target (`swift test` with Swift Testing) covers: level
  transitions fire exactly once, recovery only on red/orange -> green,
  hysteresis holds zones near boundaries, reminder scheduling math.
  Test cases are adapted from TokenEater's existing test suite.
- **Dashboard (bun test)**: JSONL parse + downsample + carry-forward helpers
  as a pure module, tested alongside the existing `merge.test.js` suite;
  smoke test extended to assert the Limits section renders with the inline
  data block present and with it absent.

## Out of scope

Panel ring colors keep their current styling (not switched to Smart Color),
menu bar gauge images (numbers only), widgets/WidgetKit, pacing schedules,
localization, themes.
