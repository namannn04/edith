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
