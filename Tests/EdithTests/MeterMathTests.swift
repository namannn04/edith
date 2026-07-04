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
