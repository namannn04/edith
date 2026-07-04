# Limits Menu Bar + Notifications + History Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Session/weekly limit percentages as a second menu bar item, TokenEater's full notification strategy (thresholds + Smart Color + pacing + reminders), and limits history recorded per poll with a 24h panel chart and a full dashboard section.

**Architecture:** All three features hang off `UsageStore`'s existing 5-minute poll. New files per responsibility: pure math (`LimitMath`), notification state machine (`LimitNotifier`), JSONL history (`LimitsHistory`), AppKit status item (`LimitsStatusItem`), Swift Charts panel view (`LimitsChartView`). Dashboard side: pure helpers in `js/limits.js` (shared by node-side `render.mjs` and the browser), a Chart.js card in `js/limitsChart.js`.

**Tech Stack:** Swift 6 toolchain (language mode v5), SwiftUI + AppKit + UserNotifications + Swift Charts (all system frameworks, macOS 14 target), Swift Testing for unit tests. Dashboard: ES modules bundled by bun, Chart.js 4.5 (already loaded via CDN `<script>`), `bun test`.

**Spec:** `docs/superpowers/specs/2026-07-04-limits-menubar-notifications-history-design.md`

## Global Constraints

- Platform floor: `.macOS(.v14)` (Package.swift) — Swift Charts is available; do not raise it.
- No new package dependencies, Swift or JS. Chart.js is already a global (`Chart`) from the template's CDN script.
- Defaults copied from TokenEater: warning **60%**, critical **85%**, Smart Color **on** with the **balanced** profile constants, pacing margin **10pp**.
- Notification copy is hardcoded English (tables in Task 2/3) — no localization.
- `dashboard/data/` and `dashboard/dashboard.html` are gitignored; never commit them.
- Commit messages: subject (+ optional body) only. **No AI attribution of any kind** (no Co-Authored-By, no "Generated with" lines). Match repo style: sentence case, no `feat:` prefixes (e.g. "System tab, tab reordering, smoother panel animations").
- TokenEater reference source (read-only, gitignored): `local/extras/TokenEater/`.
- Work directly on `main` (user's explicit choice).
- All new UserDefaults keys ride the existing SettingsBackup mirror automatically — nothing to do there.
- `swift build` runs from repo root; Swift tests run via `./test.sh` (wraps `swift test` with the CLT Testing.framework search paths — bare `swift test` fails on this machine); `bun test` / `bun build.mjs` run from `dashboard/`.

### UserDefaults key registry (used across tasks — exact strings)

| Key | Type | Default |
|---|---|---|
| `limitsInMenuBar` | Bool | true |
| `notifyMaster` | Bool | false |
| `notifyTrackSession` / `notifyTrackWeekly` | Bool | true / true |
| `notifyRecovery` | Bool | true |
| `notifyPacingWarning` / `notifyPacingHot` | Bool | true / true |
| `notifyReminderSession` | Bool | false |
| `notifyReminderSessionOffsetMin` | Int | 30 |
| `notifyReminderWeekly` | Bool | false |
| `notifyReminderWeeklyOffsetMin` | Int | 120 |
| `notifyTokenExpired` | Bool | true |
| `smartColor` | Bool | true |
| `pacingMargin` | Double | 10 |
| `warnPercent` / `critPercent` | Int | 60 / 85 |
| `notifSessionLevel` / `notifWeeklyLevel` | Int (UsageLevel raw) | 0 |
| `notifSessionPacing` / `notifWeeklyPacing` | String (PacingZone raw) | "onTrack" |
| `notifTokenExpiredAt` | Date | – |

Read pattern for defaulted-true/non-zero keys (matches `AppServices.tabEnabled`): `d.object(forKey: k) as? Bool ?? true`.

---

### Task 1: Pure limit math + Swift test target

**Files:**
- Modify: `Package.swift`
- Create: `Sources/Edith/Usage/LimitMath.swift`
- Test: `Tests/EdithTests/LimitMathTests.swift`

**Interfaces:**
- Consumes: nothing (pure Foundation).
- Produces: `UsageThresholds` (warningPercent/criticalPercent Ints, `.default` = 60/85), `UsageLevel` (green=0/orange=1/red=2, `from(pct:thresholds:)`), `PacingZone` (chill/onTrack/warning/hot, String raw), `LimitWindowKind` (.session/.weekly, `.duration`), `LimitMath.smartRisk(utilization:resetsAt:windowDuration:pacingMargin:now:) -> Double`, `LimitMath.level(forRisk:) -> UsageLevel`, `LimitMath.zone(forRisk:previous:) -> PacingZone`, `LimitMath.pacingDelta(utilization:resetsAt:windowDuration:now:) -> Double`, `LimitMath.pacingZone(delta:margin:) -> PacingZone`.

- [ ] **Step 1: Add the test target to Package.swift**

```swift
// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Edith",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Edith",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "EdithTests",
            dependencies: ["Edith"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
```

- [ ] **Step 2: Write the failing tests**

Create `Tests/EdithTests/LimitMathTests.swift`:

```swift
import Foundation
import Testing
@testable import Edith

@Suite struct LimitMathTests {
    // Fixed clock: window ends 1h from "now" on a 5h window -> e = 0.8
    let now = Date(timeIntervalSince1970: 1_750_000_000)

    @Test func thresholdLevels() {
        let t = UsageThresholds.default // 60 / 85
        #expect(UsageLevel.from(pct: 59, thresholds: t) == .green)
        #expect(UsageLevel.from(pct: 60, thresholds: t) == .orange)
        #expect(UsageLevel.from(pct: 85, thresholds: t) == .red)
    }

    @Test func highAbsoluteAlwaysFeelsRed() {
        // 98% with no reset info: absolute smoothstep(0.5, 1.0, 0.98) ~= 0.998
        let r = LimitMath.smartRisk(utilization: 98, resetsAt: nil, windowDuration: 0, pacingMargin: 10, now: now)
        #expect(r > 0.85)
        #expect(LimitMath.level(forRisk: r) == .red)
        #expect(LimitMath.smartRisk(utilization: 100, resetsAt: nil, windowDuration: 0, pacingMargin: 10, now: now) == 1.0)
    }

    @Test func earlyWindowHighRateIsDampened() {
        // 30% used, only 6 min into a 5h window (e = 0.02): confidence ~= 0.095
        // suppresses the huge projection; risk stays below the warning band.
        let resets = now.addingTimeInterval(5 * 3600 - 360)
        let r = LimitMath.smartRisk(utilization: 30, resetsAt: resets, windowDuration: 5 * 3600, pacingMargin: 10, now: now)
        #expect(LimitMath.level(forRisk: r) == .green)
    }

    @Test func lateWindowOverpaceEscalates() {
        // 80% used at e = 0.5 of a 5h window: projected 1.6x, well over pace.
        let resets = now.addingTimeInterval(2.5 * 3600)
        let r = LimitMath.smartRisk(utilization: 80, resetsAt: resets, windowDuration: 5 * 3600, pacingMargin: 10, now: now)
        #expect(LimitMath.level(forRisk: r) == .red)
    }

    @Test func hysteresisHoldsZoneNearBoundary() {
        #expect(LimitMath.zone(forRisk: 0.76, previous: nil) == .warning)  // below rising hot 0.78
        #expect(LimitMath.zone(forRisk: 0.76, previous: .hot) == .hot)     // held until < 0.73
        #expect(LimitMath.zone(forRisk: 0.72, previous: .hot) == .warning) // falls through
        #expect(LimitMath.zone(forRisk: 0.28, previous: .onTrack) == .onTrack) // held until < 0.25
    }

    @Test func pacingDeltaAndZones() {
        // Halfway through the window at 75% used -> delta = +25pp.
        let resets = now.addingTimeInterval(2.5 * 3600)
        let d = LimitMath.pacingDelta(utilization: 75, resetsAt: resets, windowDuration: 5 * 3600, now: now)
        #expect(abs(d - 25) < 0.01)
        #expect(LimitMath.pacingZone(delta: -15, margin: 10) == .chill)
        #expect(LimitMath.pacingZone(delta: 5, margin: 10) == .onTrack)
        #expect(LimitMath.pacingZone(delta: 15, margin: 10) == .warning)
        #expect(LimitMath.pacingZone(delta: 25, margin: 10) == .hot)
    }
}
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `swift test 2>&1 | tail -5`
Expected: compile error, `cannot find 'LimitMath' in scope` (and friends).

- [ ] **Step 4: Implement LimitMath**

Create `Sources/Edith/Usage/LimitMath.swift`. This is TokenEater's `SmartColor.swift` risk math + `PacingCalculator` core, ported with the **balanced** profile inlined as constants (no profile picker, no pacing schedules):

```swift
import Foundation

/// Threshold-mode config (user-tunable in Settings). Smart mode ignores these
/// and is self-calibrated by the balanced-profile constants below.
struct UsageThresholds: Equatable {
    var warningPercent: Int
    var criticalPercent: Int
    static let `default` = UsageThresholds(warningPercent: 60, criticalPercent: 85)

    static func fromDefaults(_ d: UserDefaults = .standard) -> UsageThresholds {
        UsageThresholds(
            warningPercent: d.object(forKey: "warnPercent") as? Int ?? 60,
            criticalPercent: d.object(forKey: "critPercent") as? Int ?? 85)
    }
}

enum UsageLevel: Int, Comparable {
    case green = 0, orange = 1, red = 2
    static func < (lhs: UsageLevel, rhs: UsageLevel) -> Bool { lhs.rawValue < rhs.rawValue }

    static func from(pct: Double, thresholds: UsageThresholds) -> UsageLevel {
        if pct >= Double(thresholds.criticalPercent) { return .red }
        if pct >= Double(thresholds.warningPercent) { return .orange }
        return .green
    }
}

enum PacingZone: String {
    case chill, onTrack, warning, hot
}

enum LimitWindowKind: String {
    case session, weekly
    var duration: TimeInterval { self == .session ? 5 * 3600 : 7 * 24 * 3600 }
}

/// Smart-color risk model, ported from TokenEater (SmartColor.swift) with the
/// "balanced" profile inlined. Pure functions; risk is a continuous [0,1]
/// score combining absolute usage, end-of-window projection, and pacing.
enum LimitMath {
    // Balanced-profile constants (TokenEater SmartColorProfile.balanced).
    static let k = 5.0            // confidence growth rate
    static let projUpper = 1.4    // projection-overflow smoothstep upper bound
    static let absoluteLower = 0.50
    static let absoluteUpper = 1.00
    static let risingChill = 0.30, risingWarning = 0.55, risingHot = 0.78
    static let fallingChill = 0.25, fallingWarning = 0.50, fallingHot = 0.73

    /// Hermite-smoothed step: 0 at <= a, 1 at >= b, C1-continuous between.
    static func smoothstep(_ a: Double, _ b: Double, _ x: Double) -> Double {
        guard a < b else { return x >= b ? 1 : 0 }
        let t = max(0, min(1, (x - a) / (b - a)))
        return t * t * (3 - 2 * t)
    }

    /// Confidence in the rate estimate, 0 -> ~1 across the window; dampens
    /// projection/pacing risk early when a few elapsed minutes make the rate noisy.
    static func confidence(e: Double) -> Double { 1 - exp(-k * max(0, e)) }

    /// Combined risk: max of absolute (dampened by projection health),
    /// projection overflow, and pacing delta. u, e, m all in [0,1].
    static func combinedRisk(u: Double, e: Double, m: Double) -> Double {
        if u >= 1.0 { return 1.0 }
        let aRaw = smoothstep(absoluteLower, absoluteUpper, u)
        let projectionHealth = e > 0.0001 ? smoothstep(0.7, 1.0, u / e) : 1.0
        let a = aRaw * projectionHealth
        let b: Double = {
            guard u > 0.0001, e > 0.0001 else { return 0 }
            return smoothstep(1.0, projUpper, u / e) * confidence(e: e)
        }()
        let c = smoothstep(m, m + 0.15, u - e) * confidence(e: e)
        return max(a, max(b, c))
    }

    /// Risk for a limit window. utilization in 0..100; falls back to pure
    /// absolute risk when there's no reset date to derive elapsed time from.
    static func smartRisk(
        utilization: Double, resetsAt: Date?, windowDuration: TimeInterval,
        pacingMargin: Double, now: Date = Date()
    ) -> Double {
        if utilization >= 100 { return 1.0 }
        let u = max(0, utilization) / 100
        guard let resetsAt, windowDuration > 0 else {
            return smoothstep(absoluteLower, absoluteUpper, u)
        }
        let remaining = max(0, resetsAt.timeIntervalSince(now))
        let e = max(0.0, 1.0 - min(1.0, remaining / windowDuration))
        return combinedRisk(u: u, e: e, m: pacingMargin / 100)
    }

    /// 3-level mapping used by notifications and the menu bar (TokenEater legacyLevel).
    static func level(forRisk risk: Double) -> UsageLevel {
        if risk >= 0.78 { return .red }
        if risk >= 0.50 { return .orange }
        return .green
    }

    /// 4-zone discretisation with falling-edge hysteresis (5pp buffer).
    static func zone(forRisk risk: Double, previous: PacingZone? = nil) -> PacingZone {
        let r = max(0, min(1, risk))
        func rising() -> PacingZone {
            if r >= risingHot { return .hot }
            if r >= risingWarning { return .warning }
            if r >= risingChill { return .onTrack }
            return .chill
        }
        guard let previous else { return rising() }
        switch previous {
        case .chill: return rising()
        case .onTrack:
            if r >= risingHot { return .hot }
            if r >= risingWarning { return .warning }
            if r < fallingChill { return .chill }
            return .onTrack
        case .warning:
            if r >= risingHot { return .hot }
            if r < fallingChill { return .chill }
            if r < fallingWarning { return .onTrack }
            return .warning
        case .hot:
            if r < fallingChill { return .chill }
            if r < fallingWarning { return .onTrack }
            if r < fallingHot { return .warning }
            return .hot
        }
    }

    /// Pacing: actual utilization minus the linear "expected by now" pace, in
    /// percentage points. Full-window only (TokenEater's schedule feature not ported).
    static func pacingDelta(
        utilization: Double, resetsAt: Date, windowDuration: TimeInterval, now: Date = Date()
    ) -> Double {
        let start = resetsAt.addingTimeInterval(-windowDuration)
        let elapsed = min(max(now.timeIntervalSince(start) / windowDuration, 0), 1)
        return utilization - elapsed * 100
    }

    /// chill < -margin <= onTrack <= +margin < warning <= 2*margin < hot
    static func pacingZone(delta: Double, margin: Double) -> PacingZone {
        if delta < -margin { return .chill }
        if delta <= margin { return .onTrack }
        if delta <= margin * 2 { return .warning }
        return .hot
    }
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `swift test 2>&1 | tail -5`
Expected: all `LimitMathTests` pass. (First run compiles the whole app target — slow once, fine after.)

- [ ] **Step 6: Commit**

```bash
git add Package.swift Sources/Edith/Usage/LimitMath.swift Tests/EdithTests/LimitMathTests.swift
git commit -m "Limit math: smart-color risk model + pacing zones, with a test target"
```

---

### Task 2: Notification decision engine (pure)

**Files:**
- Create: `Sources/Edith/Usage/LimitNotifierLogic.swift`
- Test: `Tests/EdithTests/LimitNotifierLogicTests.swift`

**Interfaces:**
- Consumes: `LimitWindow` (from `UsageStore.swift`: `percent: Double`, `resetsAt: Date?`), everything from Task 1.
- Produces:
  - `struct LimitAlert: Equatable { let id: String; let title: String; let body: String }`
  - `struct NotifySettings` (fields mirror the key registry; `static func fromDefaults(_:)`)
  - `struct LimitNotifierState: Equatable { var sessionLevel: UsageLevel; var weeklyLevel: UsageLevel; var sessionPacing: PacingZone; var weeklyPacing: PacingZone }` with `init()` defaulting to green/onTrack
  - `enum LimitNotifierLogic { static func decide(session: LimitWindow?, week: LimitWindow?, settings: NotifySettings, state: inout LimitNotifierState, now: Date) -> [LimitAlert] }`
  - `LimitNotifierLogic.countdown(from:to:) -> String` ("2 h 15 min"), `.dateTime(_:) -> String`, `.time(_:) -> String`

- [ ] **Step 1: Write the failing tests**

Create `Tests/EdithTests/LimitNotifierLogicTests.swift`:

```swift
import Foundation
import Testing
@testable import Edith

@Suite struct LimitNotifierLogicTests {
    let now = Date(timeIntervalSince1970: 1_750_000_000)
    var settings: NotifySettings {
        var s = NotifySettings()
        s.master = true
        s.smartColor = false // threshold mode -> deterministic levels from pct
        return s
    }

    func decide(_ session: LimitWindow?, _ week: LimitWindow?, settings: NotifySettings, state: inout LimitNotifierState) -> [LimitAlert] {
        LimitNotifierLogic.decide(session: session, week: week, settings: settings, state: &state, now: now)
    }

    @Test func masterOffProducesNothing() {
        var s = settings; s.master = false
        var state = LimitNotifierState()
        let session = LimitWindow(percent: 95, resetsAt: now.addingTimeInterval(3600))
        #expect(decide(session, nil, settings: s, state: &state).isEmpty)
        #expect(state == LimitNotifierState()) // no state churn either
    }

    @Test func escalationFiresOncePerLevel() {
        var state = LimitNotifierState()
        let session = LimitWindow(percent: 70, resetsAt: now.addingTimeInterval(3600))
        let first = decide(session, nil, settings: settings, state: &state)
        #expect(first.count == 1)
        #expect(first[0].id == "escalation_session")
        #expect(state.sessionLevel == .orange)
        // same level again -> silent
        #expect(decide(session, nil, settings: settings, state: &state).isEmpty)
    }

    @Test func redEscalationAndRecovery() {
        var state = LimitNotifierState()
        let hot = LimitWindow(percent: 90, resetsAt: now.addingTimeInterval(1800))
        let red = decide(hot, nil, settings: settings, state: &state)
        #expect(red.count == 1)
        #expect(red[0].title == "5h almost capped")
        #expect(red[0].body.contains("30 min"))
        // window resets -> back to green -> recovery notification
        let fresh = LimitWindow(percent: 0, resetsAt: now.addingTimeInterval(5 * 3600))
        let rec = decide(fresh, nil, settings: settings, state: &state)
        #expect(rec.count == 1)
        #expect(rec[0].id == "recovery_session")
        #expect(rec[0].title == "5h cleared")
    }

    @Test func recoveryRespectsToggle() {
        var s = settings; s.recovery = false
        var state = LimitNotifierState(); state.sessionLevel = .red
        let fresh = LimitWindow(percent: 0, resetsAt: now.addingTimeInterval(5 * 3600))
        #expect(decide(fresh, nil, settings: s, state: &state).isEmpty)
        #expect(state.sessionLevel == .green) // state still advances
    }

    @Test func weeklyCopyUsesDates() {
        var state = LimitNotifierState()
        let week = LimitWindow(percent: 65, resetsAt: now.addingTimeInterval(3 * 86400))
        let a = decide(nil, week, settings: settings, state: &state)
        #expect(a.count == 1)
        #expect(a[0].title == "Weekly filling up")
        #expect(a[0].body.hasPrefix("Resets "))
    }

    @Test func pacingEntryAlerts() {
        var state = LimitNotifierState()
        // Threshold-green (30%) but way ahead of pace: 30% at 4% elapsed of the week.
        let week = LimitWindow(percent: 30, resetsAt: now.addingTimeInterval(6.7 * 86400))
        let alerts = decide(nil, week, settings: settings, state: &state)
        #expect(alerts.contains { $0.id == "pacing_weekly_hot" && $0.title == "Burning hot" })
        #expect(state.weeklyPacing == .hot)
        // still hot -> silent
        #expect(decide(nil, week, settings: settings, state: &state).isEmpty)
    }

    @Test func paceDrivenWeeklyEscalationWording() {
        var s = settings; s.smartColor = true
        var state = LimitNotifierState()
        // 55% used at ~14% elapsed of the week: absolute level is green (55 < 60)
        // but smart risk escalates on projection (u/e ~ 3.9, confidence ~ 0.51 ->
        // risk ~ 0.51 = orange) -> "ahead of pace" copy, not "almost capped".
        let week = LimitWindow(percent: 55, resetsAt: now.addingTimeInterval(6.0 * 86400))
        let alerts = decide(nil, week, settings: s, state: &state)
        let esc = alerts.first { $0.id == "escalation_weekly" }
        #expect(esc != nil)
        #expect(esc!.title == "Ahead of weekly pace")
    }

    @Test func countdownFormatting() {
        #expect(LimitNotifierLogic.countdown(from: now, to: now.addingTimeInterval(45 * 60)) == "45 min")
        #expect(LimitNotifierLogic.countdown(from: now, to: now.addingTimeInterval(2 * 3600 + 15 * 60)) == "2 h 15 min")
        #expect(LimitNotifierLogic.countdown(from: now, to: now.addingTimeInterval(3 * 3600)) == "3 h")
        #expect(LimitNotifierLogic.countdown(from: now, to: now.addingTimeInterval(26 * 3600)) == "1 d 2 h")
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter LimitNotifierLogicTests 2>&1 | tail -5`
Expected: compile error, `cannot find 'NotifySettings' in scope`.

- [ ] **Step 3: Implement the decision engine**

Create `Sources/Edith/Usage/LimitNotifierLogic.swift`. Port of TokenEater's `NotificationService.evaluate/checkSurface/checkPacingTransition` for the session + weekly surfaces, copy hardcoded from its en.lproj strings:

```swift
import Foundation

struct LimitAlert: Equatable {
    let id: String
    let title: String
    let body: String
}

struct NotifySettings {
    var master = false
    var trackSession = true, trackWeekly = true
    var recovery = true
    var pacingWarning = true, pacingHot = true
    var reminderSession = false; var reminderSessionOffsetMin = 30
    var reminderWeekly = false; var reminderWeeklyOffsetMin = 120
    var tokenExpired = true
    var smartColor = true
    var pacingMargin = 10.0
    var thresholds = UsageThresholds.default

    static func fromDefaults(_ d: UserDefaults = .standard) -> NotifySettings {
        var s = NotifySettings()
        s.master = d.bool(forKey: "notifyMaster")
        s.trackSession = d.object(forKey: "notifyTrackSession") as? Bool ?? true
        s.trackWeekly = d.object(forKey: "notifyTrackWeekly") as? Bool ?? true
        s.recovery = d.object(forKey: "notifyRecovery") as? Bool ?? true
        s.pacingWarning = d.object(forKey: "notifyPacingWarning") as? Bool ?? true
        s.pacingHot = d.object(forKey: "notifyPacingHot") as? Bool ?? true
        s.reminderSession = d.bool(forKey: "notifyReminderSession")
        s.reminderSessionOffsetMin = d.object(forKey: "notifyReminderSessionOffsetMin") as? Int ?? 30
        s.reminderWeekly = d.bool(forKey: "notifyReminderWeekly")
        s.reminderWeeklyOffsetMin = d.object(forKey: "notifyReminderWeeklyOffsetMin") as? Int ?? 120
        s.tokenExpired = d.object(forKey: "notifyTokenExpired") as? Bool ?? true
        s.smartColor = d.object(forKey: "smartColor") as? Bool ?? true
        s.pacingMargin = d.object(forKey: "pacingMargin") as? Double ?? 10
        s.thresholds = UsageThresholds.fromDefaults(d)
        return s
    }
}

struct LimitNotifierState: Equatable {
    var sessionLevel: UsageLevel = .green
    var weeklyLevel: UsageLevel = .green
    var sessionPacing: PacingZone = .onTrack
    var weeklyPacing: PacingZone = .onTrack
}

/// Edge-triggered notification decisions, ported from TokenEater's
/// NotificationService. Pure: state in/out, alerts returned; the caller
/// persists state and hands alerts to UNUserNotificationCenter.
enum LimitNotifierLogic {
    static func decide(
        session: LimitWindow?, week: LimitWindow?,
        settings: NotifySettings, state: inout LimitNotifierState, now: Date = Date()
    ) -> [LimitAlert] {
        guard settings.master else { return [] }
        var alerts: [LimitAlert] = []

        let sessionPacing = pacing(session, kind: .session, margin: settings.pacingMargin, now: now)
        let weeklyPacing = pacing(week, kind: .weekly, margin: settings.pacingMargin, now: now)

        if settings.trackSession, let session {
            alerts += checkSurface(.session, window: session, pacing: sessionPacing,
                                   settings: settings, level: &state.sessionLevel, now: now)
        }
        if settings.trackWeekly, let week {
            alerts += checkSurface(.weekly, window: week, pacing: weeklyPacing,
                                   settings: settings, level: &state.weeklyLevel, now: now)
        }
        if let z = sessionPacing {
            alerts += checkPacing(z, surface: .session, settings: settings, last: &state.sessionPacing)
        }
        if let z = weeklyPacing {
            alerts += checkPacing(z, surface: .weekly, settings: settings, last: &state.weeklyPacing)
        }
        return alerts
    }

    private static func pacing(_ window: LimitWindow?, kind: LimitWindowKind, margin: Double, now: Date) -> PacingZone? {
        guard let window, let resetsAt = window.resetsAt else { return nil }
        let delta = LimitMath.pacingDelta(
            utilization: window.percent, resetsAt: resetsAt, windowDuration: kind.duration, now: now)
        return LimitMath.pacingZone(delta: delta, margin: margin)
    }

    private static func checkSurface(
        _ kind: LimitWindowKind, window: LimitWindow, pacing: PacingZone?,
        settings: NotifySettings, level previous: inout UsageLevel, now: Date
    ) -> [LimitAlert] {
        let absolute = UsageLevel.from(pct: window.percent, thresholds: settings.thresholds)
        let current: UsageLevel = settings.smartColor
            ? LimitMath.level(forRisk: LimitMath.smartRisk(
                utilization: window.percent, resetsAt: window.resetsAt,
                windowDuration: kind.duration, pacingMargin: settings.pacingMargin, now: now))
            : absolute
        guard current != previous else { return [] }
        let prev = previous
        previous = current

        // Smart escalated ABOVE the raw threshold on the weekly surface: driven
        // by rate/projection, not the cap - say "ahead of pace", not "capped".
        let paceDriven = settings.smartColor && current > absolute && kind == .weekly

        if current > prev {
            return [escalation(kind, level: current, window: window, pacing: pacing, paceDriven: paceDriven, now: now)]
        }
        if current == .green, prev > .green, settings.recovery {
            return [recovery(kind, window: window, now: now)]
        }
        return []
    }

    private static func checkPacing(
        _ zone: PacingZone, surface: LimitWindowKind,
        settings: NotifySettings, last: inout PacingZone
    ) -> [LimitAlert] {
        guard zone != last else { return [] }
        last = zone
        // Only entry into a loud zone notifies; recovery is silent by design.
        switch zone {
        case .hot where settings.pacingHot:
            return [LimitAlert(id: "pacing_\(surface.rawValue)_hot",
                               title: "Burning hot", body: "Way ahead of pace, pump the brakes")]
        case .warning where settings.pacingWarning:
            return [LimitAlert(id: "pacing_\(surface.rawValue)_warning",
                               title: "Drifting fast", body: "A touch faster than ideal, keep an eye")]
        default:
            return []
        }
    }

    // MARK: - Copy (adapted from TokenEater en.lproj)

    private static func escalation(
        _ kind: LimitWindowKind, level: UsageLevel, window: LimitWindow,
        pacing: PacingZone?, paceDriven: Bool, now: Date
    ) -> LimitAlert {
        let id = "escalation_\(kind.rawValue)"
        if paceDriven {
            return LimitAlert(id: id, title: "Ahead of weekly pace",
                body: "You're ahead of an even weekly burn rate, not near the cap. Fine if intentional.")
        }
        switch kind {
        case .session:
            let left = window.resetsAt.flatMap { $0 > now ? countdown(from: now, to: $0) : nil }
            if level == .red {
                return LimitAlert(id: id, title: "5h almost capped",
                    body: left.map { "Easy until reset, \($0) left" } ?? "Limit almost reached")
            }
            let zone = pacing ?? .onTrack
            let title: String
            switch zone {
            case .chill: title = "Pace check"
            case .onTrack: title = "Session getting heavy"
            case .warning: title = "Drifting on the 5h"
            case .hot: title = "Burning the 5h"
            }
            let body: String
            if let left {
                switch zone {
                case .chill: body = "Pace is fine, resets in \(left)"
                case .onTrack: body = "On track, resets in \(left)"
                case .warning: body = "A touch fast, \(left) left"
                case .hot: body = "Way ahead of pace, \(left) left"
                }
            } else {
                body = "Past the warning level"
            }
            return LimitAlert(id: id, title: title, body: body)
        case .weekly:
            let when = window.resetsAt.flatMap { $0 > now ? dateTime($0) : nil }
            if level == .red {
                return LimitAlert(id: id, title: "Weekly almost capped",
                    body: when.map { "Take it slow until \($0)" } ?? "Weekly limit almost reached")
            }
            return LimitAlert(id: id, title: "Weekly filling up",
                body: when.map { "Resets \($0)" } ?? "Past the weekly warning")
        }
    }

    private static func recovery(_ kind: LimitWindowKind, window: LimitWindow, now: Date) -> LimitAlert {
        let id = "recovery_\(kind.rawValue)"
        switch kind {
        case .session:
            let at = window.resetsAt.flatMap { $0 > now ? time($0) : nil }
            return LimitAlert(id: id, title: "5h cleared",
                body: at.map { "Fresh slate at \($0)" } ?? "Fresh slate, you're back")
        case .weekly:
            let at = window.resetsAt.flatMap { $0 > now ? dateTime($0) : nil }
            return LimitAlert(id: id, title: "Weekly reset",
                body: at.map { "New cycle, you're back at \($0)" } ?? "New cycle, you're back")
        }
    }

    // MARK: - Formatting

    static func countdown(from now: Date, to target: Date) -> String {
        let mins = max(0, Int(target.timeIntervalSince(now)) / 60)
        let h = mins / 60, m = mins % 60
        if h >= 24 { return "\(h / 24) d \(h % 24) h" }
        if h > 0 { return m > 0 ? "\(h) h \(m) min" : "\(h) h" }
        return "\(m) min"
    }

    static func dateTime(_ d: Date) -> String {
        d.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day().hour().minute())
    }

    static func time(_ d: Date) -> String {
        d.formatted(date: .omitted, time: .shortened)
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test 2>&1 | tail -5`
Expected: all suites pass. If a smart-mode test disagrees by a hair, print the computed risk for its inputs and adjust the TEST input to land clearly inside the intended band — never bend the ported math to a test.

- [ ] **Step 5: Commit**

```bash
git add Sources/Edith/Usage/LimitNotifierLogic.swift Tests/EdithTests/LimitNotifierLogicTests.swift
git commit -m "Notification decision engine: threshold + smart + pacing edges, TokenEater copy"
```

---

### Task 3: Notification delivery + UsageStore wiring

**Files:**
- Create: `Sources/Edith/Usage/LimitNotifier.swift`
- Modify: `Sources/Edith/Usage/UsageStore.swift` (init/apply/fetchLimitsOnce)

**Interfaces:**
- Consumes: Task 2's `LimitNotifierLogic.decide`, `NotifySettings.fromDefaults()`, `LimitAlert`.
- Produces: `@MainActor final class LimitNotifier: NSObject, UNUserNotificationCenterDelegate` with `func evaluate(session: LimitWindow?, week: LimitWindow?)`, `func notifyTokenExpired()`, `func sendTest()`, `func requestPermission()`, `func authorizationStatus() async -> UNAuthorizationStatus`. `UsageStore` gains `let notifier = LimitNotifier()` (internal, Settings uses it).

- [ ] **Step 1: Implement LimitNotifier**

Create `Sources/Edith/Usage/LimitNotifier.swift`:

```swift
import Foundation
import UserNotifications

/// Delivery layer around LimitNotifierLogic: persists edge-trigger state in
/// UserDefaults, posts UNNotifications, and (re)schedules reset reminders on
/// every poll so moving reset times never stack duplicates.
@MainActor
final class LimitNotifier: NSObject, UNUserNotificationCenterDelegate {
    private let defaults = UserDefaults.standard
    private var center: UNUserNotificationCenter { .current() }

    func evaluate(session: LimitWindow?, week: LimitWindow?) {
        let settings = NotifySettings.fromDefaults()
        guard settings.master else {
            // Master off: drop pending reminders so re-enabling can't fire stale ones.
            center.removePendingNotificationRequests(withIdentifiers: ["reminder_session", "reminder_weekly"])
            return
        }
        var state = loadState()
        let before = state
        let alerts = LimitNotifierLogic.decide(
            session: session, week: week, settings: settings, state: &state, now: Date())
        if state != before { save(state) }
        for alert in alerts { send(alert) }
        scheduleReminders(session: session, week: week, settings: settings)
    }

    func notifyTokenExpired() {
        let settings = NotifySettings.fromDefaults()
        guard settings.master, settings.tokenExpired else { return }
        // ponytail: 1-per-hour dedupe via a plain timestamp, like TokenEater
        if let last = defaults.object(forKey: "notifTokenExpiredAt") as? Date,
           Date().timeIntervalSince(last) < 3600 { return }
        defaults.set(Date(), forKey: "notifTokenExpiredAt")
        send(LimitAlert(id: "token_expired",
                        title: "Claude token expired", body: "Run claude to log in again"))
    }

    func sendTest() {
        send(LimitAlert(id: "test_\(UUID().uuidString)",
                        title: "Hey, you're set", body: "If you see this, notifications work"))
    }

    func requestPermission() {
        center.delegate = self
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    /// Banners + sound even while Edith is frontmost.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter, willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    // MARK: - State persistence

    private func loadState() -> LimitNotifierState {
        var s = LimitNotifierState()
        s.sessionLevel = UsageLevel(rawValue: defaults.integer(forKey: "notifSessionLevel")) ?? .green
        s.weeklyLevel = UsageLevel(rawValue: defaults.integer(forKey: "notifWeeklyLevel")) ?? .green
        s.sessionPacing = PacingZone(rawValue: defaults.string(forKey: "notifSessionPacing") ?? "") ?? .onTrack
        s.weeklyPacing = PacingZone(rawValue: defaults.string(forKey: "notifWeeklyPacing") ?? "") ?? .onTrack
        return s
    }

    private func save(_ s: LimitNotifierState) {
        defaults.set(s.sessionLevel.rawValue, forKey: "notifSessionLevel")
        defaults.set(s.weeklyLevel.rawValue, forKey: "notifWeeklyLevel")
        defaults.set(s.sessionPacing.rawValue, forKey: "notifSessionPacing")
        defaults.set(s.weeklyPacing.rawValue, forKey: "notifWeeklyPacing")
    }

    // MARK: - Sending

    private func send(_ alert: LimitAlert) {
        let content = UNMutableNotificationContent()
        content.title = alert.title
        content.body = alert.body
        content.sound = .default
        center.add(UNNotificationRequest(identifier: alert.id, content: content, trigger: nil))
    }

    private func scheduleReminders(session: LimitWindow?, week: LimitWindow?, settings: NotifySettings) {
        center.removePendingNotificationRequests(withIdentifiers: ["reminder_session", "reminder_weekly"])
        if settings.reminderSession, let reset = session?.resetsAt {
            schedule(id: "reminder_session",
                     title: "Session resets in \(offsetLabel(settings.reminderSessionOffsetMin))",
                     body: "Save your spot or send it",
                     at: reset.addingTimeInterval(-Double(settings.reminderSessionOffsetMin) * 60))
        }
        if settings.reminderWeekly, let reset = week?.resetsAt {
            schedule(id: "reminder_weekly",
                     title: "Weekly resets in \(offsetLabel(settings.reminderWeeklyOffsetMin))",
                     body: "Last lap on the cycle",
                     at: reset.addingTimeInterval(-Double(settings.reminderWeeklyOffsetMin) * 60))
        }
    }

    private func schedule(id: String, title: String, body: String, at fire: Date) {
        guard fire.timeIntervalSinceNow > 0 else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let comps = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second], from: fire)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    /// Matches the Settings picker labels: round hours as "2 h", else "30 min".
    private func offsetLabel(_ minutes: Int) -> String {
        minutes >= 60 && minutes % 60 == 0 ? "\(minutes / 60) h" : "\(minutes) min"
    }
}
```

- [ ] **Step 2: Wire into UsageStore**

In `Sources/Edith/Usage/UsageStore.swift`:

Add the property next to the other private vars (after `private var process: Process?`):

```swift
    let notifier = LimitNotifier()
```

In `apply(_ usage:)`, append after `retryNotBefore = nil`:

```swift
        notifier.evaluate(session: session, week: week)
```

In `fetchLimitsOnce()`, in the unauthorized re-fetch FAILURE branch (the `else` that sets `limitsError = "Token expired - run claude to re-login"`), add:

```swift
                notifier.notifyTokenExpired()
```

- [ ] **Step 3: Build and test**

Run: `swift build 2>&1 | tail -3 && swift test 2>&1 | tail -3`
Expected: clean build, tests still pass.

- [ ] **Step 4: Commit**

```bash
git add Sources/Edith/Usage/LimitNotifier.swift Sources/Edith/Usage/UsageStore.swift
git commit -m "Limit notifications: delivery, reset reminders, token-expired, store wiring"
```

---

### Task 4: Limits history JSONL

**Files:**
- Create: `Sources/Edith/Usage/LimitsHistory.swift`
- Modify: `Sources/Edith/Usage/UsageStore.swift` (apply + history loading)
- Test: `Tests/EdithTests/LimitsHistoryTests.swift`

**Interfaces:**
- Consumes: `LimitWindow`, `Repo.root`.
- Produces:
  - `struct LimitsHistory` with `mutating func append(session: LimitWindow?, week: LimitWindow?, now: Date)` writing to `dashboard/data/limits-history.jsonl`, and pure `static func row(session:week:now:) -> (key: String, line: String)` (testable).
  - `struct LimitPoint: Identifiable { let date: Date; let s: Double?; let w: Double?; var id: Date { date } }`
  - `static func parse(_ text: String, since: Date) -> [LimitPoint]`
  - `UsageStore` gains `@Published private(set) var limitPoints: [LimitPoint]` and `func loadLimitHistory() async`.

- [ ] **Step 1: Write the failing tests**

Create `Tests/EdithTests/LimitsHistoryTests.swift`:

```swift
import Foundation
import Testing
@testable import Edith

@Suite struct LimitsHistoryTests {
    let now = Date(timeIntervalSince1970: 1_750_000_000)

    @Test func rowIsOneJSONLineAndKeyIgnoresTimestamp() throws {
        let s = LimitWindow(percent: 42.14, resetsAt: now.addingTimeInterval(3600))
        let w = LimitWindow(percent: 67.3, resetsAt: now.addingTimeInterval(86400))
        let a = LimitsHistory.row(session: s, week: w, now: now)
        let b = LimitsHistory.row(session: s, week: w, now: now.addingTimeInterval(300))
        #expect(a.key == b.key)                    // same values -> same key, any time
        #expect(a.line.hasSuffix("\n"))
        let obj = try JSONSerialization.jsonObject(
            with: Data(a.line.utf8)) as! [String: Any]
        #expect(obj["s"] as! Double == 42.1)       // rounded to 0.1
        #expect(obj["w"] as! Double == 67.3)
        #expect(obj["ts"] is String)
        #expect(obj["sr"] is String)
    }

    @Test func rowHandlesNils() throws {
        let a = LimitsHistory.row(session: nil, week: nil, now: now)
        let obj = try JSONSerialization.jsonObject(with: Data(a.line.utf8)) as! [String: Any]
        // JSONEncoder omits nil optionals - absent keys, not JSON nulls. The JS
        // parser treats absent and null identically (`typeof o.s === "number"`).
        #expect(obj["s"] == nil)
        #expect(obj["sr"] == nil)
        #expect(obj["ts"] is String)
    }

    @Test func parseSkipsGarbageAndFiltersByDate() {
        let iso = ISO8601DateFormatter()
        let old = iso.string(from: now.addingTimeInterval(-100_000))
        let fresh = iso.string(from: now.addingTimeInterval(-100))
        let text = """
        {"ts":"\(old)","s":10,"w":20,"sr":null,"wr":null}
        not json
        {"ts":"\(fresh)","s":42.1,"w":67.3,"sr":null,"wr":null}
        """
        let pts = LimitsHistory.parse(text, since: now.addingTimeInterval(-86400))
        #expect(pts.count == 1)
        #expect(pts[0].s == 42.1)
        #expect(pts[0].w == 67.3)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter LimitsHistoryTests 2>&1 | tail -3`
Expected: compile error, `cannot find 'LimitsHistory' in scope`.

- [ ] **Step 3: Implement LimitsHistory**

Create `Sources/Edith/Usage/LimitsHistory.swift`:

```swift
import Foundation

/// Append-only JSONL of limit polls: {"ts","s","w","sr","wr"} per line.
/// s/w = session/weekly percent (0.1 precision), sr/wr = reset ISO dates.
/// Rows identical to the previous one (ignoring ts) are skipped, so an idle
/// machine writes nothing. dashboard/data/ is gitignored.
struct LimitsHistory {
    static var url: URL { Repo.root.appendingPathComponent("dashboard/data/limits-history.jsonl") }

    private var lastKey: String?
    private var seeded = false

    private struct Row: Codable {
        let ts: String
        let s: Double?
        let w: Double?
        let sr: String?
        let wr: String?
    }

    private static let iso = ISO8601DateFormatter()

    /// Pure row builder: dedupe key (values sans timestamp) + the JSONL line.
    static func row(session: LimitWindow?, week: LimitWindow?, now: Date) -> (key: String, line: String) {
        let round1 = { (v: Double) in (v * 10).rounded() / 10 }
        let r = Row(
            ts: iso.string(from: now),
            s: session.map { round1($0.percent) },
            w: week.map { round1($0.percent) },
            sr: session?.resetsAt.map { iso.string(from: $0) },
            wr: week?.resetsAt.map { iso.string(from: $0) })
        let key = "\(r.s ?? -1)|\(r.w ?? -1)|\(r.sr ?? "-")|\(r.wr ?? "-")"
        // Codable keeps this future-proof; key order in the line doesn't matter.
        let data = (try? JSONEncoder().encode(r)) ?? Data("{}".utf8)
        return (key, String(decoding: data, as: UTF8.self) + "\n")
    }

    mutating func append(session: LimitWindow?, week: LimitWindow?, now: Date = Date()) {
        if !seeded { seed() }
        let (key, line) = Self.row(session: session, week: week, now: now)
        guard key != lastKey else { return }
        lastKey = key
        let url = Self.url
        let fm = FileManager.default
        try? fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if !fm.fileExists(atPath: url.path) {
            try? Data(line.utf8).write(to: url)
            return
        }
        if let handle = try? FileHandle(forWritingTo: url) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: Data(line.utf8))
        }
    }

    /// Seed the dedupe key from the file's last line so an app restart on an
    /// idle machine doesn't write a duplicate row.
    private mutating func seed() {
        seeded = true
        guard let data = try? Data(contentsOf: Self.url),
              let text = String(data: data, encoding: .utf8) else { return }
        guard let line = text.split(separator: "\n").last,
              let row = try? JSONDecoder().decode(Row.self, from: Data(line.utf8)) else { return }
        lastKey = "\(row.s ?? -1)|\(row.w ?? -1)|\(row.sr ?? "-")|\(row.wr ?? "-")"
    }

    // MARK: - Reading (panel chart)

    static func parse(_ text: String, since: Date) -> [LimitPoint] {
        var out: [LimitPoint] = []
        let decoder = JSONDecoder()
        for line in text.split(separator: "\n") {
            guard let row = try? decoder.decode(Row.self, from: Data(line.utf8)),
                  let date = UsageStore.parseISO(row.ts), date >= since else { continue }
            out.append(LimitPoint(date: date, s: row.s, w: row.w))
        }
        return out.sorted { $0.date < $1.date }
    }
}

struct LimitPoint: Identifiable, Equatable {
    let date: Date
    let s: Double?
    let w: Double?
    var id: Date { date }
}
```

- [ ] **Step 4: Wire into UsageStore**

In `Sources/Edith/Usage/UsageStore.swift`:

Add properties (next to `let notifier`):

```swift
    private var history = LimitsHistory()
    @Published private(set) var limitPoints: [LimitPoint] = []
    private var historyMtime: Date?
```

In `apply(_ usage:)`, after `notifier.evaluate(...)`:

```swift
        history.append(session: session, week: week)
```

Add near `loadStats()`:

```swift
    /// Last-24h limit curve for the panel chart; mtime-gated like loadStats.
    func loadLimitHistory() async {
        let url = LimitsHistory.url
        let mtime = (try? FileManager.default.attributesOfItem(atPath: url.path)[.modificationDate]) as? Date
        if let mtime, mtime == historyMtime { return }
        historyMtime = mtime
        let since = Date().addingTimeInterval(-24 * 3600)
        let points = await Task.detached(priority: .utility) {
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { return [LimitPoint]() }
            return LimitsHistory.parse(text, since: since)
        }.value
        limitPoints = points
    }
```

In `shutdown()`, add `limitPoints = []` next to the other resets.

- [ ] **Step 5: Run tests + build**

Run: `swift test 2>&1 | tail -3`
Expected: all pass.

- [ ] **Step 6: Commit**

```bash
git add Sources/Edith/Usage/LimitsHistory.swift Sources/Edith/Usage/UsageStore.swift Tests/EdithTests/LimitsHistoryTests.swift
git commit -m "Record limits history to dashboard/data/limits-history.jsonl on every poll"
```

---

### Task 5: Menu bar numbers item

**Files:**
- Create: `Sources/Edith/Usage/LimitsStatusItem.swift`
- Modify: `Sources/Edith/App.swift:192-224` (`clickStatusItem`, `centerPanelUnderIcon`)
- Modify: `Sources/Edith/Usage/UsageStore.swift` (create/update/teardown)

**Interfaces:**
- Consumes: `LimitMath.smartRisk`, `UsageLevel.from`, `UsageThresholds.fromDefaults`, `LimitWindow`, `togglePanel()`.
- Produces: `@MainActor final class LimitsStatusItem` with `init()`, `func update(session: LimitWindow?, week: LimitWindow?)`, `func showUnavailable()`, `func remove()`, and `static private(set) var window: NSWindow?` (the item's own status window — excluded by App.swift's lookups). `UsageStore` gains `func syncStatusItem()` and `func refreshMenuBarItem()`.

- [ ] **Step 1: Implement LimitsStatusItem**

Create `Sources/Edith/Usage/LimitsStatusItem.swift`:

```swift
import AppKit

/// Second menu bar item: "S 42  W 67", each number tinted by its own risk.
/// Clicking it toggles the main Edith panel. Created/destroyed by UsageStore
/// from the "limitsInMenuBar" setting.
@MainActor
final class LimitsStatusItem {
    /// This item's own status window. clickStatusItem()/centerPanelUnderIcon()
    /// exclude it when hunting for the MenuBarExtra's window. nonisolated(unsafe)
    /// because those are plain non-isolated globals (App.swift has no isolation
    /// annotations); everything actually runs on the main thread.
    nonisolated(unsafe) static private(set) var window: NSWindow?

    private let item: NSStatusItem

    init() {
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.target = self
        item.button?.action = #selector(clicked)
        Self.window = item.button?.window
        showUnavailable()
    }

    func remove() {
        NSStatusBar.system.removeStatusItem(item)
        Self.window = nil
    }

    @objc private func clicked() { togglePanel() }

    func update(session: LimitWindow?, week: LimitWindow?) {
        let title = NSMutableAttributedString()
        segment("S", window: session, kind: .session, into: title)
        title.append(NSAttributedString(string: "  "))
        segment("W", window: week, kind: .weekly, into: title)
        item.button?.attributedTitle = title
    }

    func showUnavailable() { update(session: nil, week: nil) }

    private func segment(
        _ label: String, window: LimitWindow?, kind: LimitWindowKind,
        into out: NSMutableAttributedString
    ) {
        out.append(NSAttributedString(string: label + " ", attributes: [
            .font: NSFont.systemFont(ofSize: 9, weight: .bold),
            .foregroundColor: NSColor.secondaryLabelColor,
            .baselineOffset: 1.5,
        ]))
        let numberFont = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .semibold)
        guard let window else {
            out.append(NSAttributedString(string: "\u{2013}", attributes: [
                .font: numberFont, .foregroundColor: NSColor.tertiaryLabelColor,
            ]))
            return
        }
        out.append(NSAttributedString(string: "\(Int(window.percent.rounded()))", attributes: [
            .font: numberFont, .foregroundColor: color(for: window, kind: kind),
        ]))
    }

    // MARK: - Color

    private func color(for window: LimitWindow, kind: LimitWindowKind) -> NSColor {
        let d = UserDefaults.standard
        if d.object(forKey: "smartColor") as? Bool ?? true {
            let risk = LimitMath.smartRisk(
                utilization: window.percent, resetsAt: window.resetsAt,
                windowDuration: kind.duration,
                pacingMargin: d.object(forKey: "pacingMargin") as? Double ?? 10)
            return Self.color(forRisk: risk)
        }
        switch UsageLevel.from(pct: window.percent, thresholds: .fromDefaults(d)) {
        case .green: return .systemGreen
        case .orange: return .systemOrange
        case .red: return .systemRed
        }
    }

    /// Continuous risk color, TokenEater's 4-stop gradient: green until 0.30,
    /// green->orange to 0.55, orange->red to 0.85, red beyond. HSB-space
    /// interpolation keeps the midpoints vivid instead of muddy sRGB olives.
    static func color(forRisk risk: Double) -> NSColor {
        let r = max(0, min(1, risk))
        let green = NSColor.systemGreen, orange = NSColor.systemOrange, red = NSColor.systemRed
        if r <= 0.30 { return green }
        if r >= 0.85 { return red }
        if r <= 0.55 { return interpolateHSB(green, orange, t: (r - 0.30) / 0.25) }
        return interpolateHSB(orange, red, t: (r - 0.55) / 0.30)
    }

    private static func interpolateHSB(_ a: NSColor, _ b: NSColor, t: Double) -> NSColor {
        let f = CGFloat(max(0, min(1, t)))
        guard let x = a.usingColorSpace(.sRGB), let y = b.usingColorSpace(.sRGB) else { return a }
        let dh = y.hueComponent - x.hueComponent
        // short-path hue interpolation around the wheel
        let h: CGFloat
        if abs(dh) <= 0.5 { h = (x.hueComponent + dh * f + 1).truncatingRemainder(dividingBy: 1) }
        else if dh > 0.5 { h = (x.hueComponent + (dh - 1) * f + 1).truncatingRemainder(dividingBy: 1) }
        else { h = (x.hueComponent + (dh + 1) * f + 1).truncatingRemainder(dividingBy: 1) }
        return NSColor(
            hue: h,
            saturation: x.saturationComponent + (y.saturationComponent - x.saturationComponent) * f,
            brightness: x.brightnessComponent + (y.brightnessComponent - x.brightnessComponent) * f,
            alpha: 1)
    }
}
```

- [ ] **Step 2: Disambiguate the status-window lookups in App.swift**

Both `clickStatusItem()` (line ~192) and `centerPanelUnderIcon()` (line ~217) match the FIRST `StatusBarWindow` — wrong once a second status item exists. Replace both lookups with a shared helper. In `Sources/Edith/App.swift`, above `clickStatusItem()`:

```swift
/// The MenuBarExtra's own status window. With the limits item in the bar
/// there are two of our StatusBarWindows; exclude the limits one explicitly.
/// No isolation annotation - matches the surrounding plain globals
/// (clickStatusItem, centerPanelUnderIcon), which all run on main in practice.
private func menuBarExtraStatusWindow() -> NSWindow? {
    NSApp.windows.first {
        $0.className.contains("StatusBarWindow") && $0 !== LimitsStatusItem.window
    }
}
```

In `clickStatusItem()` change:

```swift
    if let statusWindow = NSApp.windows.first(where: { $0.className.contains("StatusBarWindow") }),
```

to:

```swift
    if let statusWindow = menuBarExtraStatusWindow(),
```

In `centerPanelUnderIcon(_:)` change:

```swift
    guard let icon = NSApp.windows.first(where: { $0.className.contains("StatusBarWindow") })
    else { return }
```

to:

```swift
    guard let icon = menuBarExtraStatusWindow() else { return }
```

- [ ] **Step 3: Wire into UsageStore**

In `Sources/Edith/Usage/UsageStore.swift`:

Add property (next to `private var history`):

```swift
    private var statusItem: LimitsStatusItem?
```

At the end of `init()` (inside, after the `Task { ... }` block), add:

```swift
        syncStatusItem()
```

Add methods (near `shutdown()`):

```swift
    /// Reconcile the menu bar numbers item with the "limitsInMenuBar" setting.
    func syncStatusItem() {
        let on = UserDefaults.standard.object(forKey: "limitsInMenuBar") as? Bool ?? true
        if on, statusItem == nil {
            statusItem = LimitsStatusItem()
            statusItem?.update(session: session, week: week)
        }
        if !on, let item = statusItem {
            item.remove()
            statusItem = nil
        }
    }

    /// Re-render after settings that affect colors change (thresholds, smart color).
    func refreshMenuBarItem() {
        statusItem?.update(session: session, week: week)
    }
```

In `apply(_ usage:)`, after `history.append(...)`:

```swift
        statusItem?.update(session: session, week: week)
```

In `fetchLimitsOnce()`, add `statusItem?.showUnavailable()` in all three error paths:
- after `limitsError = "Claude Code token not found"`
- after `limitsError = "Token expired - run claude to re-login"`
- after `limitsError = "Offline"`

In `shutdown()`, add:

```swift
        statusItem?.remove()
        statusItem = nil
```

- [ ] **Step 4: Build and eyeball**

Run: `swift build 2>&1 | tail -3 && ./build.sh`
Expected: builds; app relaunches with `S 42  W 67`-style numbers next to the glasses icon. Click the numbers — the panel must open AND stay centered under the GLASSES icon (that's the App.swift disambiguation working; if the panel centers under the numbers, the exclusion is wrong). Toggle works from both icons; Esc still closes.

- [ ] **Step 5: Commit**

```bash
git add Sources/Edith/Usage/LimitsStatusItem.swift Sources/Edith/App.swift Sources/Edith/Usage/UsageStore.swift
git commit -m "Menu bar limits item: risk-tinted session/weekly numbers"
```

---

### Task 6: Settings UI (limits + notifications)

**Files:**
- Modify: `Sources/Edith/Settings/SettingsView.swift`

**Interfaces:**
- Consumes: `services.usage?.syncStatusItem()`, `services.usage?.refreshMenuBarItem()`, `services.usage?.notifier` (`requestPermission`, `sendTest`, `authorizationStatus()`), UserDefaults keys from the registry.
- Produces: two new cards between the GENERAL and THEME cards.

- [ ] **Step 1: Add the @AppStorage properties**

In `SettingsView`, after the existing `@AppStorage` block (line ~34):

```swift
    @AppStorage("limitsInMenuBar") private var limitsInMenuBar = true
    @AppStorage("smartColor") private var smartColor = true
    @AppStorage("warnPercent") private var warnPercent = 60
    @AppStorage("critPercent") private var critPercent = 85
    @AppStorage("pacingMargin") private var pacingMargin = 10.0
    @AppStorage("notifyMaster") private var notifyMaster = false
    @AppStorage("notifyTrackSession") private var notifyTrackSession = true
    @AppStorage("notifyTrackWeekly") private var notifyTrackWeekly = true
    @AppStorage("notifyRecovery") private var notifyRecovery = true
    @AppStorage("notifyPacingWarning") private var notifyPacingWarning = true
    @AppStorage("notifyPacingHot") private var notifyPacingHot = true
    @AppStorage("notifyReminderSession") private var reminderSession = false
    @AppStorage("notifyReminderSessionOffsetMin") private var reminderSessionOffset = 30
    @AppStorage("notifyReminderWeekly") private var reminderWeekly = false
    @AppStorage("notifyReminderWeeklyOffsetMin") private var reminderWeeklyOffset = 120
    @AppStorage("notifyTokenExpired") private var notifyTokenExpired = true
    @State private var notifDenied = false
```

- [ ] **Step 2: Add the two cards**

In `body`, insert between the GENERAL card (`.card()` closing at line ~99) and the THEME card. Reuse the row idiom already in the file (Text + Spacer + Toggle). Small helpers keep it readable — add these private funcs at the bottom of `SettingsView`:

```swift
    private func toggleRow(_ title: String, subtitle: String? = nil, isOn: Binding<Bool>) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13))
                if let subtitle {
                    Text(subtitle).font(.system(size: 10)).foregroundStyle(.tertiary)
                }
            }
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden().toggleStyle(.switch).controlSize(.small).tint(theme)
        }
    }
```

The LIMITS card:

```swift
            VStack(alignment: .leading, spacing: 12) {
                eyebrow("LIMITS")
                toggleRow("Show in menu bar",
                          subtitle: "Session + weekly percentages next to the clock",
                          isOn: $limitsInMenuBar)
                toggleRow("Smart color",
                          subtitle: "Time-aware risk drives colors and alerts",
                          isOn: $smartColor)
                HStack {
                    Text("Warning / critical").font(.system(size: 13))
                    Spacer()
                    Stepper("\(warnPercent)%", value: $warnPercent, in: 10...critPercent - 5, step: 5)
                        .font(.system(size: 12)).fixedSize()
                    Stepper("\(critPercent)%", value: $critPercent, in: warnPercent + 5...100, step: 5)
                        .font(.system(size: 12)).fixedSize()
                }
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Pacing margin").font(.system(size: 13))
                        Text("How far ahead of even pace counts as drifting")
                            .font(.system(size: 10)).foregroundStyle(.tertiary)
                    }
                    Spacer()
                    Stepper("±\(Int(pacingMargin))pp", value: $pacingMargin, in: 5...25, step: 5)
                        .font(.system(size: 12)).fixedSize()
                }
            }
            .card()
            .onChange(of: limitsInMenuBar) { services.usage?.syncStatusItem() }
            .onChange(of: smartColor) { services.usage?.refreshMenuBarItem() }
            .onChange(of: warnPercent) { services.usage?.refreshMenuBarItem() }
            .onChange(of: critPercent) { services.usage?.refreshMenuBarItem() }
            .onChange(of: pacingMargin) { services.usage?.refreshMenuBarItem() }
```

The NOTIFICATIONS card, right after:

```swift
            VStack(alignment: .leading, spacing: 12) {
                eyebrow("NOTIFICATIONS")
                toggleRow("Enable notifications",
                          subtitle: notifDenied
                            ? "Denied in System Settings > Notifications > Edith"
                            : "Alerts for limit levels, pacing, resets",
                          isOn: $notifyMaster)
                Group {
                    toggleRow("Session (5h) alerts", isOn: $notifyTrackSession)
                    toggleRow("Weekly alerts", isOn: $notifyTrackWeekly)
                    toggleRow("Recovery (back to green)", isOn: $notifyRecovery)
                    toggleRow("Pacing: drifting fast", isOn: $notifyPacingWarning)
                    toggleRow("Pacing: burning hot", isOn: $notifyPacingHot)
                    toggleRow("Token expired", isOn: $notifyTokenExpired)
                    HStack {
                        toggleRow("Remind before session reset", isOn: $reminderSession)
                        Picker("", selection: $reminderSessionOffset) {
                            Text("5 min").tag(5); Text("15 min").tag(15)
                            Text("30 min").tag(30); Text("1 h").tag(60)
                        }
                        .labelsHidden().pickerStyle(.menu).fixedSize()
                        .disabled(!reminderSession)
                    }
                    HStack {
                        toggleRow("Remind before weekly reset", isOn: $reminderWeekly)
                        Picker("", selection: $reminderWeeklyOffset) {
                            Text("1 h").tag(60); Text("2 h").tag(120)
                            Text("6 h").tag(360); Text("12 h").tag(720)
                        }
                        .labelsHidden().pickerStyle(.menu).fixedSize()
                        .disabled(!reminderWeekly)
                    }
                    Button("Send test notification") {
                        services.usage?.notifier.sendTest()
                    }
                    .buttonStyle(HoverButtonStyle())
                    .font(.system(size: 12))
                    .foregroundStyle(theme)
                }
                .disabled(!notifyMaster)
                .opacity(notifyMaster ? 1 : 0.45)
            }
            .card()
            .onChange(of: notifyMaster) {
                if notifyMaster {
                    services.usage?.notifier.requestPermission()
                    Task {
                        // brief delay so the permission dialog result lands first
                        try? await Task.sleep(nanoseconds: 500_000_000)
                        notifDenied = await services.usage?.notifier.authorizationStatus() == .denied
                    }
                }
            }
            .task {
                notifDenied = await services.usage?.notifier.authorizationStatus() == .denied
            }
```

Note: if the Usage tab is disabled, `services.usage` is nil and the buttons no-op — acceptable; the whole feature lives in the Usage module.

- [ ] **Step 3: Build and verify by hand**

Run: `./build.sh`
Expected checklist:
- LIMITS card: menu bar toggle removes/re-adds the numbers item live; steppers clamp (warning can't cross critical).
- NOTIFICATIONS card: flipping master ON triggers the macOS permission prompt; "Send test notification" produces a banner; sub-rows dim when master is off.

- [ ] **Step 4: Commit**

```bash
git add Sources/Edith/Settings/SettingsView.swift
git commit -m "Settings: limits menu bar + smart color + thresholds + notification toggles"
```

---

### Task 7: Panel 24h limits chart

**Files:**
- Create: `Sources/Edith/Usage/LimitsChartView.swift`
- Modify: `Sources/Edith/Usage/UsageView.swift` (limitsCard + .task)

**Interfaces:**
- Consumes: `store.limitPoints: [LimitPoint]`, `store.loadLimitHistory()`, `themeColor(_:)`.
- Produces: `struct LimitsChartView: View { let points: [LimitPoint]; let theme: Color }`.

- [ ] **Step 1: Implement the chart view**

Create `Sources/Edith/Usage/LimitsChartView.swift`:

```swift
import Charts
import SwiftUI

/// Compact last-24h limits curve: session (theme color) + weekly (gray),
/// stepped lines with dashed threshold rules. Points are sparse (writes are
/// deduped) - stepEnd interpolation carries values forward, and a synthetic
/// tail point extends each line to "now".
struct LimitsChartView: View {
    let points: [LimitPoint]
    let theme: Color
    @AppStorage("warnPercent") private var warn = 60
    @AppStorage("critPercent") private var crit = 85

    private struct Sample: Identifiable {
        let date: Date
        let value: Double
        let series: String
        var id: String { "\(series)-\(date.timeIntervalSince1970)" }
    }

    private var samples: [Sample] {
        var out: [Sample] = []
        let now = Date()
        for (key, name) in [(\LimitPoint.s, "Session"), (\LimitPoint.w, "Weekly")] {
            let pts = points.compactMap { p in p[keyPath: key].map { (p.date, $0) } }
            out += pts.map { Sample(date: $0.0, value: $0.1, series: name) }
            if let last = pts.last, last.0 < now { // carry the last value to now
                out.append(Sample(date: now, value: last.1, series: name))
            }
        }
        return out
    }

    var body: some View {
        Chart {
            ForEach(samples) { s in
                LineMark(
                    x: .value("Time", s.date),
                    y: .value("Percent", s.value),
                    series: .value("Series", s.series))
                    .interpolationMethod(.stepEnd)
                    .lineStyle(StrokeStyle(lineWidth: 1.5))
                    .foregroundStyle(by: .value("Series", s.series))
            }
            RuleMark(y: .value("Warning", warn))
                .foregroundStyle(.orange.opacity(0.35))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
            RuleMark(y: .value("Critical", crit))
                .foregroundStyle(.red.opacity(0.35))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
        }
        .chartForegroundStyleScale(["Session": theme, "Weekly": Color.secondary])
        .chartYScale(domain: 0...100)
        .chartYAxis {
            AxisMarks(values: [0, 50, 100]) {
                AxisGridLine().foregroundStyle(.primary.opacity(0.08))
                AxisValueLabel().font(.system(size: 8)).foregroundStyle(.tertiary)
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .hour, count: 6)) {
                AxisValueLabel(format: .dateTime.hour())
                    .font(.system(size: 8)).foregroundStyle(.tertiary)
            }
        }
        .chartLegend(position: .top, alignment: .trailing, spacing: 4)
        .frame(height: 84)
    }
}
```

- [ ] **Step 2: Mount it in the limits card**

In `Sources/Edith/Usage/UsageView.swift`, inside `limitsCard`'s `VStack`, after the `HStack(spacing: 12) { ring(...) ring(...) }` block:

```swift
            if !store.limitPoints.isEmpty {
                LimitsChartView(points: store.limitPoints, theme: theme)
                    .padding(.top, 2)
            }
```

And extend the view's `.task` (line ~19):

```swift
        .task {
            await store.loadStats() // panel open → pick up fresh snapshots
            await store.loadLimitHistory()
        }
```

- [ ] **Step 3: Build and eyeball**

Run: `./build.sh`
Expected: after at least two polls (or with an existing `dashboard/data/limits-history.jsonl`), the limits card shows the mini chart under the rings; with no history file the card looks exactly as before.

- [ ] **Step 4: Commit**

```bash
git add Sources/Edith/Usage/LimitsChartView.swift Sources/Edith/Usage/UsageView.swift
git commit -m "Panel: 24h limits history chart under the rings"
```

---

### Task 8: Dashboard data plumbing (limits.mjs + inline block)

**Files:**
- Create: `dashboard/limits.mjs` (dashboard root, next to `merge.mjs` — NOT under `js/`: render.mjs runs under plain node, and with no package.json a `.js` file is CommonJS there; root-level `.mjs` is this repo's convention for pure modules shared between node and the tests/bundle, exactly like `merge.mjs`)
- Test: `dashboard/tests/limits.test.js`
- Modify: `dashboard/dashboard.template.html` (add the `limits-data` block)
- Modify: `dashboard/render.mjs` (inline limits payload)
- Modify: `dashboard/build.mjs` (preserve the limits-data block)

**Interfaces:**
- Consumes: `dashboard/data/limits-history.jsonl` rows `{"ts","s","w","sr","wr"}` (Task 4's writer).
- Produces (ES module `limits.mjs`, pure — used by node's render.mjs AND the browser bundle):
  - `parseLimitsJSONL(text) -> [{t, s, w, sr, wr}]` (epoch-ms, sorted ascending, garbage skipped)
  - `downsampleLimits(rows, nowMs, rawWindowMs = 7*864e5) -> rows` (raw within window; older → hourly maxima)
  - `sliceRange(points, nowMs, ms|null) -> points`
  - `resetMarkers(points) -> [{t, kind: "session"|"weekly"}]`
  - Inline payload shape: `{"points": [...]}` in `<script id="limits-data" type="application/json">`.

- [ ] **Step 1: Write the failing tests**

Create `dashboard/tests/limits.test.js`:

```js
import { test, expect } from "bun:test";
import { parseLimitsJSONL, downsampleLimits, sliceRange, resetMarkers } from "../limits.mjs";

const H = 36e5;
const NOW = Date.parse("2026-07-04T12:00:00Z");
const iso = (t) => new Date(t).toISOString();
const line = (t, s, w, sr = null, wr = null) =>
  JSON.stringify({ ts: iso(t), s, w, sr: sr && iso(sr), wr: wr && iso(wr) });

test("parseLimitsJSONL skips garbage, sorts, converts to epoch ms", () => {
  const text = [line(NOW, 42.1, 67.3), "not json", "", line(NOW - H, 10, 20)].join("\n");
  const rows = parseLimitsJSONL(text);
  expect(rows.length).toBe(2);
  expect(rows[0].t).toBe(NOW - H);
  expect(rows[1].s).toBe(42.1);
  expect(rows[0].sr).toBeNull();
});

test("downsampleLimits keeps recent raw, buckets older to hourly maxima", () => {
  const old = NOW - 8 * 864e5; // 8 days ago, beyond the 7d raw window
  const rows = parseLimitsJSONL([
    line(old, 10, 5),
    line(old + 10 * 60e3, 30, 5),   // same hour, higher session -> bucket max
    line(old + 20 * 60e3, 20, 8),
    line(NOW - H, 42, 67),          // recent -> kept raw
    line(NOW, 44, 67),
  ].join("\n"));
  const out = downsampleLimits(rows, NOW);
  expect(out.length).toBe(3);      // 1 hourly bucket + 2 raw
  expect(out[0].s).toBe(30);       // max of the bucket
  expect(out[0].w).toBe(8);
  expect(out[1].s).toBe(42);
});

test("sliceRange filters by window; null means all", () => {
  const pts = [{ t: NOW - 2 * 864e5 }, { t: NOW - H }, { t: NOW }];
  expect(sliceRange(pts, NOW, 864e5).length).toBe(2);
  expect(sliceRange(pts, NOW, null).length).toBe(3);
});

test("resetMarkers fires where a reset timestamp changes", () => {
  const sr1 = NOW + 3 * H, sr2 = NOW + 8 * H, wr = NOW + 5 * 864e5;
  const pts = parseLimitsJSONL([
    line(NOW - 2 * H, 80, 50, sr1, wr),
    line(NOW - H, 5, 50, sr2, wr),   // session window rolled
    line(NOW, 10, 51, sr2, wr),
  ].join("\n"));
  const marks = resetMarkers(pts);
  expect(marks.length).toBe(1);
  expect(marks[0].kind).toBe("session");
  expect(marks[0].t).toBe(NOW - H);
});
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd dashboard && bun test tests/limits.test.js 2>&1 | tail -3`
Expected: FAIL — `Cannot find module '../limits.mjs'`.

- [ ] **Step 3: Implement limits.mjs**

Create `dashboard/limits.mjs`:

```js
// Pure helpers for the limits-history JSONL ({"ts","s","w","sr","wr"} per
// line, written by the Edith app on every poll). Used by render.mjs (node,
// to build the inline payload) and by js/limitsChart.js (browser bundle).
// Lives at the dashboard root like merge.mjs: node needs the .mjs extension
// to treat it as ESM (no package.json here). No DOM.

export function parseLimitsJSONL(text) {
  const out = [];
  for (const line of String(text || "").split("\n")) {
    if (!line.trim()) continue;
    let o;
    try { o = JSON.parse(line); } catch { continue; }
    const t = Date.parse(o.ts);
    if (!Number.isFinite(t)) continue;
    out.push({
      t,
      s: typeof o.s === "number" ? o.s : null,
      w: typeof o.w === "number" ? o.w : null,
      sr: o.sr ? Date.parse(o.sr) : null,
      wr: o.wr ? Date.parse(o.wr) : null,
    });
  }
  out.sort((a, b) => a.t - b.t);
  return out;
}

// Raw rows within rawWindowMs of now; older rows collapse to hourly buckets
// keeping each field's MAX (peaks are what matter) and the bucket's last resets.
export function downsampleLimits(rows, nowMs, rawWindowMs = 7 * 864e5) {
  const cutoff = nowMs - rawWindowMs;
  const buckets = new Map();
  const raw = [];
  for (const r of rows) {
    if (r.t >= cutoff) { raw.push(r); continue; }
    const b = Math.floor(r.t / 36e5) * 36e5;
    const cur = buckets.get(b);
    if (!cur) { buckets.set(b, { ...r, t: b }); continue; }
    if (r.s != null && (cur.s == null || r.s > cur.s)) cur.s = r.s;
    if (r.w != null && (cur.w == null || r.w > cur.w)) cur.w = r.w;
    cur.sr = r.sr; cur.wr = r.wr;
  }
  return [...buckets.values(), ...raw].sort((a, b) => a.t - b.t);
}

export function sliceRange(points, nowMs, ms) {
  return ms == null ? points : points.filter((p) => p.t >= nowMs - ms);
}

// A change in a reset timestamp between consecutive points = that window rolled.
export function resetMarkers(points) {
  const out = [];
  for (let i = 1; i < points.length; i++) {
    const p = points[i - 1], q = points[i];
    if (p.sr && q.sr && p.sr !== q.sr) out.push({ t: q.t, kind: "session" });
    if (p.wr && q.wr && p.wr !== q.wr) out.push({ t: q.t, kind: "weekly" });
  }
  return out;
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd dashboard && bun test tests/limits.test.js 2>&1 | tail -3`
Expected: 4 pass.

- [ ] **Step 5: Add the data block to the template**

In `dashboard/dashboard.template.html`, directly after the existing usage-data block:

```html
<script id="usage-data" type="application/json">
{}
</script>
```

add:

```html
<script id="limits-data" type="application/json">
{}
</script>
```

- [ ] **Step 6: Inline the payload in render.mjs**

In `dashboard/render.mjs`:

Add this import after the existing merge.mjs import:

```js
import { parseLimitsJSONL, downsampleLimits } from "./limits.mjs";
```

Then replace the final inline section (currently steps "2. inline into dashboard.html") so both blocks are written in one pass. Replace:

```js
// 2. inline into dashboard.html (regex-match the data block - contract)
const htmlPath = resolve(here, "dashboard.html");
const tmpl = readFileSync(htmlPath, "utf8");
const safe = JSON.stringify(payload).replace(/<\/script>/g, "<\\/script>");
const re = /(<script id="usage-data" type="application\/json">)([\s\S]*?)(<\/script>)/;
if (!re.test(tmpl)) {
  console.error('ERROR: could not find <script id="usage-data"> block in dashboard.html');
  process.exit(1);
}
writeFileSync(htmlPath, tmpl.replace(re, `$1\n${safe}\n$3`));
```

with:

```js
// 2. inline into dashboard.html (regex-match the data blocks - contract)
const htmlPath = resolve(here, "dashboard.html");
let html = readFileSync(htmlPath, "utf8");
const safe = JSON.stringify(payload).replace(/<\/script>/g, "<\\/script>");
const re = /(<script id="usage-data" type="application\/json">)([\s\S]*?)(<\/script>)/;
if (!re.test(html)) {
  console.error('ERROR: could not find <script id="usage-data"> block in dashboard.html');
  process.exit(1);
}
html = html.replace(re, `$1\n${safe}\n$3`);

// limits history (written by the Edith app; may not exist yet)
const limitsPath = resolve(here, "data", "limits-history.jsonl");
let limitsPayload = { points: [] };
if (existsSync(limitsPath)) {
  const rows = parseLimitsJSONL(readFileSync(limitsPath, "utf8"));
  limitsPayload = { points: downsampleLimits(rows, Date.now()) };
}
const reL = /(<script id="limits-data" type="application\/json">)([\s\S]*?)(<\/script>)/;
if (reL.test(html)) {
  const safeL = JSON.stringify(limitsPayload).replace(/<\/script>/g, "<\\/script>");
  html = html.replace(reL, `$1\n${safeL}\n$3`);
} else {
  console.error('warning: no <script id="limits-data"> block (rebuild dashboard.html with bun build.mjs)');
}
writeFileSync(htmlPath, html);
```

- [ ] **Step 7: Preserve the block across rebuilds in build.mjs**

In `dashboard/build.mjs`, replace the single-block preserve:

```js
// Preserve the live data block (render.mjs writes real usage data into it).
const dataRe =
  /<script id="usage-data" type="application\/json">[\s\S]*?<\/script>/;
if (existsSync(p("dashboard.html"))) {
  const m = readFileSync(p("dashboard.html"), "utf8").match(dataRe);
  if (m) html = html.replace(dataRe, m[0]);
}
```

with:

```js
// Preserve the live data blocks (render.mjs writes real data into them).
if (existsSync(p("dashboard.html"))) {
  const prev = readFileSync(p("dashboard.html"), "utf8");
  for (const id of ["usage-data", "limits-data"]) {
    const re = new RegExp(
      `<script id="${id}" type="application\\/json">[\\s\\S]*?<\\/script>`);
    const m = prev.match(re);
    if (m) html = html.replace(re, m[0]);
  }
}
```

- [ ] **Step 8: Run the full dashboard test suite + a build**

Run: `cd dashboard && bun test 2>&1 | tail -3 && bun build.mjs && ./cc-update`
Expected: all tests pass; build prints the KB size; cc-update ends with `rendered: ...` and NO limits warning (the freshly rebuilt dashboard.html has the block). If the app has been running since Task 4, `grep -c limits data/limits-history.jsonl` style check: `test -f data/limits-history.jsonl && wc -l data/limits-history.jsonl` shows rows, and `grep -o 'id="limits-data"' dashboard.html` confirms the block.

- [ ] **Step 9: Commit**

```bash
git add dashboard/limits.mjs dashboard/tests/limits.test.js dashboard/dashboard.template.html dashboard/render.mjs dashboard/build.mjs
git commit -m "Dashboard: inline limits-history payload with 7d-raw/hourly downsample"
```

---

### Task 9: Dashboard Limits card

**Files:**
- Create: `dashboard/js/limitsChart.js`
- Modify: `dashboard/dashboard.template.html` (card markup)
- Modify: `dashboard/js/app.js` (init call)

**Interfaces:**
- Consumes: `limits.mjs` (`sliceRange`, `resetMarkers`), `js/charts.js` (`mount`, `GRIDC`, `baseTooltip`), the `limits-data` inline block, global `Chart`.
- Produces: `initLimitsCard()` (exported from `js/limitsChart.js`), card element ids `limits-card`, `seg-limits`, canvas `c-limits`.

- [ ] **Step 1: Add the card markup**

In `dashboard/dashboard.template.html`, the grid ends with the model-table card. Find this exact closing sequence (end of the `tbl-models` card, before the grid closes and the footer starts):

```html
      </div>

    </div>

    <footer>
```

and replace with:

```html
      </div>

      <div class="card col-12" id="limits-card">
        <div class="card-head">
          <div class="card-title">Rate limits - session &amp; weekly</div>
          <div style="display:flex;align-items:center;gap:10px;flex:0 0 auto">
            <span class="card-note" style="max-width:none">% of window used · dashes = thresholds · verticals = resets</span>
            <div class="seg" id="seg-limits">
              <button data-lr="24h" aria-pressed="true">24h</button>
              <button data-lr="7d">7d</button>
              <button data-lr="30d">30d</button>
              <button data-lr="all">All</button>
            </div>
          </div>
        </div>
        <div class="chart-box"><canvas id="c-limits"></canvas></div>
      </div>

    </div>

    <footer>
```

- [ ] **Step 2: Implement limitsChart.js**

Create `dashboard/js/limitsChart.js`:

```js
// Limits history card: session + weekly utilization curves over time with
// threshold rules and reset markers. Self-contained: own range state (the
// global range controls are calendar-date based; limits are rolling-window).
import { mount, GRIDC, baseTooltip } from "./charts.js";
import { sliceRange, resetMarkers } from "../limits.mjs";

// ponytail: thresholds mirror the app defaults (60/85); the dashboard can't
// read the app's UserDefaults.
const WARN = 60, CRIT = 85;
const SESSION_C = "#d97757", WEEKLY_C = "#c89b3c";
const RANGES = { "24h": 864e5, "7d": 7 * 864e5, "30d": 30 * 864e5, all: null };
let range = "24h";
let LP = [];

const markerPlugin = {
  id: "limitResets",
  afterDatasetsDraw(chart, _args, opts) {
    const marks = (opts && opts.markers) || [];
    const { ctx, chartArea, scales } = chart;
    ctx.save();
    ctx.setLineDash([2, 3]);
    ctx.lineWidth = 1;
    for (const m of marks) {
      const x = scales.x.getPixelForValue(m.t);
      if (x < chartArea.left || x > chartArea.right) continue;
      ctx.strokeStyle = m.kind === "session" ? "rgba(217,119,87,.30)" : "rgba(200,155,60,.55)";
      ctx.beginPath();
      ctx.moveTo(x, chartArea.top);
      ctx.lineTo(x, chartArea.bottom);
      ctx.stroke();
    }
    ctx.restore();
  },
};

const thresholdPlugin = {
  id: "limitThresholds",
  afterDatasetsDraw(chart) {
    const { ctx, chartArea, scales } = chart;
    ctx.save();
    ctx.setLineDash([4, 4]);
    ctx.lineWidth = 1;
    for (const [v, color] of [[WARN, "rgba(230,140,60,.5)"], [CRIT, "rgba(200,60,50,.5)"]]) {
      const y = scales.y.getPixelForValue(v);
      ctx.strokeStyle = color;
      ctx.beginPath();
      ctx.moveTo(chartArea.left, y);
      ctx.lineTo(chartArea.right, y);
      ctx.stroke();
    }
    ctx.restore();
  },
};

export function initLimitsCard() {
  const card = document.getElementById("limits-card");
  if (!card) return;
  try {
    LP = JSON.parse(document.getElementById("limits-data")?.textContent || "{}").points || [];
  } catch (e) {
    LP = [];
  }
  if (!LP.length) {
    card.style.display = "none";
    return;
  }
  document.querySelectorAll("#seg-limits button").forEach((b) =>
    b.addEventListener("click", () => {
      range = b.dataset.lr;
      syncPills();
      renderLimits();
    }));
  syncPills();
  renderLimits();
}

function syncPills() {
  document.querySelectorAll("#seg-limits button").forEach((b) =>
    b.setAttribute("aria-pressed", String(b.dataset.lr === range)));
}

function fmtTick(v) {
  const d = new Date(v);
  if (range === "24h") return `${String(d.getHours()).padStart(2, "0")}:00`;
  return `${d.getMonth() + 1}/${d.getDate()}`;
}

function renderLimits() {
  const now = LP[LP.length - 1].t;
  const pts = sliceRange(LP, now, RANGES[range]);
  if (!pts.length) return;
  // Session windows roll every ~5h - beyond 7d the markers are pure noise.
  const marks = resetMarkers(pts).filter(
    (m) => m.kind === "weekly" || (RANGES[range] ?? Infinity) <= 7 * 864e5);
  const ds = (key, label, color) => ({
    label,
    data: pts.filter((p) => p[key] != null).map((p) => ({ x: p.t, y: p[key] })),
    borderColor: color,
    backgroundColor: color,
    stepped: true,
    pointRadius: 0,
    borderWidth: 1.5,
  });
  mount("c-limits", {
    type: "line",
    data: { datasets: [ds("s", "Session (5h)", SESSION_C), ds("w", "Weekly", WEEKLY_C)] },
    options: {
      animation: false,
      responsive: true,
      maintainAspectRatio: false,
      scales: {
        x: {
          type: "linear",
          min: pts[0].t,
          max: now,
          grid: { display: false },
          ticks: { maxTicksLimit: 10, callback: fmtTick },
        },
        y: {
          min: 0,
          max: 100,
          grid: { color: GRIDC },
          ticks: { callback: (v) => v + "%" },
        },
      },
      plugins: {
        legend: { display: true, labels: { boxWidth: 8, boxHeight: 8 } },
        tooltip: {
          ...baseTooltip,
          callbacks: {
            title: (items) => new Date(items[0].parsed.x).toLocaleString(),
            label: (item) => ` ${item.dataset.label}: ${item.parsed.y.toFixed(1)}%`,
          },
        },
        limitResets: { markers: marks },
      },
    },
    plugins: [markerPlugin, thresholdPlugin],
  });
}
```

- [ ] **Step 3: Wire into app.js**

In `dashboard/js/app.js`, add to the imports:

```js
import { initLimitsCard } from "./limitsChart.js";
```

and at the very end of the file (top level, OUTSIDE the `if (HAS_DATA)` block — the limits card must render even before the first usage snapshot, and hides itself when there are no points):

```js
// Limits card is independent of the usage payload and the global range filter.
initLimitsCard();
```

- [ ] **Step 4: Rebuild, render, verify**

Run: `cd dashboard && bun test 2>&1 | tail -3 && bun build.mjs && ./cc-update && open dashboard.html`
Expected: tests pass; the Limits card appears at the bottom with stepped session/weekly curves, dashed threshold rules at 60/85, range pills switching 24h/7d/30d/all, weekly reset verticals (gold) and session verticals (terracotta) on ≤7d ranges. With no history file the card is hidden entirely. Toggle the theme button — the chart must still be legible in both themes.

- [ ] **Step 5: Commit**

```bash
git add dashboard/js/limitsChart.js dashboard/js/app.js dashboard/dashboard.template.html
git commit -m "Dashboard: rate-limits history card with ranges, thresholds, reset markers"
```

---

### Task 10: Docs + full verification sweep

**Files:**
- Modify: `README.md` (Features list)
- Modify: `dashboard/README.md` (Files table)
- Modify: `dashboard/CHANGELOG.md` (new entry at top, matching its existing format)

**Interfaces:** none — documentation + end-to-end checks.

- [ ] **Step 1: Update README.md**

In the Features list, extend the rate-limit bullet and add two:

```markdown
- **Rate limit rings** - session (5h) and weekly usage as animated gauges
  with live second countdowns; auto-refresh every 5 min, instantly on wake;
  a 24h history mini-chart under the rings
- **Limits in the menu bar** - optional second menu bar item with the
  session + weekly percentages, tinted by a time-aware risk model (Smart
  Color) or plain thresholds; click opens the panel
- **Limit notifications** - threshold escalations with pacing-aware copy,
  ahead-of-pace and burning-hot alerts, back-to-green recovery, reminders
  before session/weekly resets, token-expired nudge - all configurable in
  Settings, off by default
```

- [ ] **Step 2: Update dashboard/README.md**

Add to the Files table:

```markdown
| `limits.mjs`, `js/limitsChart.js` | Limits-history helpers (pure, shared with render.mjs like merge.mjs) + the Limits card (Chart.js). |
| `data/limits-history.jsonl` | Limit-poll history, appended by the Edith app (one JSON line per changed poll). |
```

And in the render.mjs row (or right below the table), note: render.mjs also inlines `data/limits-history.jsonl` into the `<script id="limits-data">` block (raw ≤7 days, hourly maxima beyond).

- [ ] **Step 3: Update dashboard/CHANGELOG.md**

Read the top of the file first and mimic its entry format exactly (heading style, date format). Content: Limits card (session/weekly curves, 24h/7d/30d/all, threshold rules, reset markers), fed by app-written `limits-history.jsonl` inlined at render time.

- [ ] **Step 4: Full verification sweep**

```bash
swift test 2>&1 | tail -3                      # all Swift suites green
cd dashboard && bun test 2>&1 | tail -3        # all dashboard suites green
bun build.mjs && ./cc-update                   # build + render clean
cd .. && ./build.sh --install                  # ship it to /Applications
```

Manual checklist (app running):
1. Menu bar shows `S nn  W nn` with sane colors; hide/show via Settings works.
2. Click numbers → panel opens, centered under the glasses icon.
3. Settings → enable notifications → permission prompt → test notification lands.
4. Panel limits card shows the 24h chart (needs ≥2 changed polls or an existing file).
5. `dashboard/data/limits-history.jsonl` grows on value changes only (poll twice idle → no new row).
6. Dashboard Limits card renders in browser, both themes, all four ranges.
7. Disable the Usage tab in Settings → menu bar numbers disappear, no timers left (Console clean); re-enable → everything returns.

- [ ] **Step 5: Commit**

```bash
git add README.md dashboard/README.md dashboard/CHANGELOG.md
git commit -m "Document menu bar limits, notifications, and limits history"
```

---

## Self-Review Notes

- **Spec coverage:** menu bar numbers (T5), window-lookup fix (T5), full notification strategy incl. Smart Color + pacing + reminders + recovery + token-expired + test button (T1-T3, T6), settings table (T6), history JSONL with dedupe (T4), panel 24h chart (T7), dashboard inline + downsample (T8), Limits card with ranges/thresholds/markers (T9), Swift + bun tests (T1, T2, T4, T8), docs (T10). Spec's "hidden until data" panel behavior: T7 `if !store.limitPoints.isEmpty`. Spec's error handling: T5 `showUnavailable()` on all three error paths; T3 master-off reminder cleanup.
- **Known intentional deviations:** none. Sonnet/Design/vendor/extra-credits/profiles/schedules are out of scope per spec.
- **Type consistency spot-checks:** `LimitWindow(percent:resetsAt:)` matches `UsageStore.swift:4-7`; `LimitNotifierLogic.decide` signature identical in T2 tests, T2 impl, T3 caller; `LimitPoint` fields (`date/s/w`) match T4 producer and T7 consumer; JSONL field names (`ts/s/w/sr/wr`) match T4 writer, T4 parser, T8 JS parser, T8 tests.
