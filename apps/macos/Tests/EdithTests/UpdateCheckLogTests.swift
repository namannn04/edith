import EdithKit
import Foundation
import Testing

@Suite struct UpdateCheckLogTests {
    private func tempURL() -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("update-checks-\(UUID().uuidString).json")
    }

    private func record(
        _ offset: TimeInterval, kind: UpdateCheckRecord.Kind = .automatic,
        outcome: UpdateCheckRecord.Outcome = .upToDate
    ) -> UpdateCheckRecord {
        UpdateCheckRecord(
            date: Date(timeIntervalSince1970: 1_800_000_000 + offset), kind: kind,
            outcome: outcome)
    }

    @Test func loadReturnsEmptyWhenNoFileExists() {
        #expect(UpdateCheckLog.load(from: tempURL()).isEmpty)
    }

    @Test func appendRoundTripsThroughDisk() {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url) }

        UpdateCheckLog.append(record(0, kind: .manual, outcome: .updateFound), to: url)

        let loaded = UpdateCheckLog.load(from: url)
        #expect(loaded.count == 1)
        #expect(loaded[0].kind == .manual)
        #expect(loaded[0].outcome == .updateFound)
    }

    @Test func newestRecordSortsFirst() {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url) }

        UpdateCheckLog.append(record(0), to: url)
        UpdateCheckLog.append(record(600), to: url)
        UpdateCheckLog.append(record(300), to: url)

        let dates = UpdateCheckLog.load(from: url).map(\.date)
        #expect(dates == dates.sorted(by: >))
    }

    @Test func historyIsCappedAtTheLimit() {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url) }

        for index in 0..<(UpdateCheckLog.limit + 25) {
            UpdateCheckLog.append(record(TimeInterval(index)), to: url)
        }

        #expect(UpdateCheckLog.load(from: url).count == UpdateCheckLog.limit)
    }

    @Test func countsOnlyTheRequestedKind() {
        let records = [
            record(0, kind: .automatic), record(1, kind: .manual), record(2, kind: .automatic),
        ]
        #expect(UpdateCheckLog.count(of: .automatic, in: records) == 2)
        #expect(UpdateCheckLog.count(of: .manual, in: records) == 1)
    }

    @Test func clearRemovesEveryRecord() {
        let url = tempURL()
        UpdateCheckLog.append(record(0), to: url)
        UpdateCheckLog.clear(at: url)
        #expect(UpdateCheckLog.load(from: url).isEmpty)
    }

    @Test func corruptFileDegradesToEmpty() {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url) }
        try? Data("not json".utf8).write(to: url)
        #expect(UpdateCheckLog.load(from: url).isEmpty)
    }

    @Test func summaryDescribesEachOutcome() {
        #expect(record(0, outcome: .upToDate).summary == "Up to date")
        #expect(
            UpdateCheckRecord(
                date: Date(), kind: .manual, outcome: .updateFound, version: "1.2.3"
            ).summary == "Found 1.2.3")
        #expect(
            UpdateCheckRecord(
                date: Date(), kind: .manual, outcome: .failed, detail: "offline"
            ).summary == "offline")
    }

    @Test func nearestIntervalSnapsToAChoice() {
        #expect(UpdateCheckInterval.nearest(to: 3_600).seconds == 3_600)
        #expect(UpdateCheckInterval.nearest(to: 80_000).seconds == 86_400)
        #expect(UpdateCheckInterval.nearest(to: 0).seconds == 3_600)
        #expect(UpdateCheckInterval.nearest(to: 9_999_999).seconds == 604_800)
    }

    @Test func everyIntervalChoiceIsUnique() {
        let seconds = UpdateCheckInterval.choices.map(\.seconds)
        #expect(Set(seconds).count == seconds.count)
        #expect(seconds == seconds.sorted())
    }
}
