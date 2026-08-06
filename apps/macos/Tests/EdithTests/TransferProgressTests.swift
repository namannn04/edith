import Foundation
import Testing

@testable import EdithKit

@Suite struct RsyncProgressTests {
    @Test func readsARealProgressLine() {
        let sample = RsyncProgress.parse("     32,604,160  25%   29.33MB/s    0:00:03  ")
        #expect(sample?.bytesTransferred == 32_604_160)
        #expect(sample?.percent == 25)
        #expect(sample?.bytesPerSecond == 29_330_000)
        #expect(sample?.filesRemaining == nil)
    }

    @Test func readsTheFileCounterWhenAFileFinishes() {
        let sample = RsyncProgress.parse(
            "     41,943,040  33%   31.25MB/s    0:00:01 (xfr#1, to-chk=2/4)")
        #expect(sample?.bytesTransferred == 41_943_040)
        #expect(sample?.percent == 33)
        #expect(sample?.filesRemaining == 2)
        #expect(sample?.filesTotal == 4)
    }

    @Test func splitsTheCarriageReturnStream() {
        let chunk =
            "         32,768   0%    0.00kB/s    0:00:00  \r"
            + "    125,829,120 100%   29.61MB/s    0:00:04 (xfr#3, to-chk=0/4)\r"
        let samples = RsyncProgress.lines(from: chunk)
        #expect(samples.count == 2)
        #expect(samples.first?.percent == 0)
        #expect(samples.last?.percent == 100)
        #expect(samples.last?.filesRemaining == 0)
    }

    @Test func ignoresEverythingThatIsNotAProgressRecord() {
        #expect(RsyncProgress.parse("") == nil)
        #expect(RsyncProgress.parse("sending incremental file list") == nil)
        #expect(RsyncProgress.parse("created directory /tmp/dst") == nil)
        #expect(RsyncProgress.parse("total size is 125,829,120  speedup is 1.00") == nil)
        #expect(RsyncProgress.parse("rsync: command not found") == nil)
    }

    @Test func understandsEveryRateUnit() {
        #expect(RsyncProgress.rate("0.00kB/s") == 0)
        #expect(RsyncProgress.rate("512B/s") == 512)
        #expect(RsyncProgress.rate("1.50kB/s") == 1500)
        #expect(RsyncProgress.rate("29.33MB/s") == 29_330_000)
        #expect(RsyncProgress.rate("1.39GB/s") == 1_390_000_000)
        #expect(RsyncProgress.rate("nonsense") == 0)
    }
}

@Suite struct ThroughputEstimatorTests {
    @Test func reportsNothingUntilItHasASample() {
        let estimator = ThroughputEstimator()
        let estimate = estimator.estimate(bytesRemaining: 1000)
        #expect(estimate.bytesPerSecond == 0)
        #expect(estimate.secondsRemaining == nil)
    }

    @Test func smoothsSpikesInsteadOfFollowingThem() {
        var estimator = ThroughputEstimator(weight: 0.25)
        estimator.record(bytesPerSecond: 1000)
        estimator.record(bytesPerSecond: 9000)
        let estimate = estimator.estimate(bytesRemaining: 6000)
        #expect(estimate.bytesPerSecond == 3000)
        #expect(estimate.secondsRemaining == 2)
    }

    @Test func aStalledSampleDoesNotWipeTheEstimate() {
        var estimator = ThroughputEstimator()
        estimator.record(bytesPerSecond: 2000)
        estimator.record(bytesPerSecond: 0)
        #expect(estimator.estimate(bytesRemaining: 4000).bytesPerSecond == 2000)
    }
}
