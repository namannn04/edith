import Foundation
import SwiftUI

public struct PlaybackWave: View {
    let playing: Bool
    let color: Color
    var barCount: Int
    var maxHeight: CGFloat

    public init(playing: Bool, color: Color, barCount: Int = 5, maxHeight: CGFloat = 18) {
        self.playing = playing
        self.color = color
        self.barCount = barCount
        self.maxHeight = maxHeight
    }

    private static let weights: [Double] = [0.55, 0.85, 1.0, 0.75, 0.6, 0.9, 0.5]

    public var body: some View {
        TimelineView(.animation(minimumInterval: 0.12, paused: !playing)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            HStack(spacing: 2.5) {
                ForEach(0..<barCount, id: \.self) { i in
                    Capsule()
                        .fill(color)
                        .frame(width: 3, height: height(i, t))
                }
            }
            .frame(height: maxHeight, alignment: .center)
            .animation(.easeInOut(duration: 0.3), value: playing)
        }
    }

    private func height(_ i: Int, _ t: Double) -> CGFloat {
        guard playing else { return maxHeight * 0.15 }
        let phase = sin(t * (1.8 + Double(i) * 0.37) + Double(i) * 1.7)
        let level = 0.3 + 0.7 * abs(phase)
        return maxHeight * CGFloat(max(0.15, level * Self.weights[i % Self.weights.count]))
    }
}
