import EdithKit
import SwiftUI

@MainActor
final class CompanionMindModel: ObservableObject {
    @Published private(set) var beliefs: [CompanionBelief] = []
    @Published private(set) var claims: [CompanionClaim] = []
    @Published private(set) var observations: [CompanionObservation] = []
    @Published private(set) var runs: [CompanionRun] = []
    @Published private(set) var runningNightly = false
    @Published private(set) var error: String?

    private var client: CompanionClient {
        CompanionClient(baseURL: CompanionClient.endpoint(override: nil))
    }

    func refresh() async {
        do {
            let client = client
            beliefs = try await client.beliefs(limit: 20)
            claims = try await client.claims(limit: 20)
            observations = try await client.observations(limit: 20, kind: nil)
            runs = try await client.runs(limit: 5)
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    func runNightly() async {
        guard !runningNightly else { return }
        runningNightly = true
        defer { runningNightly = false }
        do {
            _ = try await client.nightlyRun()
            await refresh()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

struct CompanionMindScreen: View {
    @ObservedObject var model: CompanionMindModel
    @Environment(\.colorScheme) private var scheme
    @Environment(\.compactLayout) private var compact
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var barsFilled = false

    private var dark: Bool { scheme == .dark }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: UIScale.pt(12)) {
                if let error = model.error {
                    Text(error)
                        .font(.system(size: UIScale.pt(11.5)))
                        .foregroundStyle(.orange)
                }
                HStack(alignment: .top, spacing: UIScale.pt(12)) {
                    beliefsCard
                    claimsCard
                }
                HStack(alignment: .top, spacing: UIScale.pt(12)) {
                    observationsCard
                    nightlyCard
                }
            }
            .pageContent(compact)
        }
        .task {
            await model.refresh()
            withAnimation(Motion.animation(Motion.settle, reduceMotion: reduceMotion)) {
                barsFilled = true
            }
        }
    }

    private var beliefsCard: some View {
        SkinCard(title: "Beliefs", dark: dark, fill: true) {
            if model.beliefs.isEmpty {
                emptyText("Nothing concluded yet. The nightly run forms beliefs from episodes.")
            } else {
                VStack(alignment: .leading, spacing: UIScale.pt(9)) {
                    ForEach(model.beliefs, id: \.id) { belief in
                        beliefRow(belief)
                    }
                }
            }
        }
    }

    private func beliefRow(_ belief: CompanionBelief) -> some View {
        let superseded = belief.status != "active"
        return VStack(alignment: .leading, spacing: UIScale.pt(4)) {
            HStack(alignment: .firstTextBaseline, spacing: UIScale.pt(6)) {
                Text(belief.statement)
                    .font(.system(size: UIScale.pt(12.5)))
                    .foregroundStyle(DashSkin.ink(dark))
                Spacer(minLength: 0)
                if superseded {
                    verdictChip("superseded", tone: .orange)
                } else {
                    Text("\(Int(belief.confidence * 100))%")
                        .font(.system(size: UIScale.pt(11)))
                        .monospacedDigit()
                        .foregroundStyle(DashSkin.inkFaint(dark))
                }
            }
            if !superseded {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule().fill(DashSkin.line(dark))
                        Capsule()
                            .fill(DashSkin.accent(dark))
                            .frame(
                                width: barsFilled
                                    ? geometry.size.width * CGFloat(belief.confidence) : 0)
                    }
                }
                .frame(height: UIScale.pt(5))
            }
        }
        .opacity(superseded ? 0.55 : 1)
        .help(
            "\(belief.kind) · first formed \(String(belief.firstFormed.prefix(10))) · \(belief.evidenceEpisodeIds.count) evidence episodes"
        )
    }

    private var claimsCard: some View {
        SkinCard(title: "Claims", dark: dark, fill: true) {
            if model.claims.isEmpty {
                emptyText("No claims extracted yet.")
            } else {
                VStack(alignment: .leading, spacing: UIScale.pt(8)) {
                    ForEach(model.claims, id: \.id) { claim in
                        HStack(alignment: .firstTextBaseline, spacing: UIScale.pt(6)) {
                            Text(claim.statement)
                                .font(.system(size: UIScale.pt(12.5)))
                                .foregroundStyle(DashSkin.ink(dark))
                                .lineLimit(2)
                            Spacer(minLength: 0)
                            claimVerdict(claim)
                        }
                        .help(claim.verdictNote ?? claim.claimType)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func claimVerdict(_ claim: CompanionClaim) -> some View {
        switch claim.verdict {
        case "corroborated":
            verdictChip("corroborated", tone: .green)
        case "contradicted":
            verdictChip("contradicted", tone: .red)
        case .some:
            verdictChip("unclear", tone: .orange)
        case nil:
            verdictChip("unchecked", tone: DashSkin.inkFaint(dark))
        }
    }

    private func verdictChip(_ label: String, tone: Color) -> some View {
        Text(label)
            .font(.system(size: UIScale.pt(9.5), weight: .bold))
            .tracking(0.4)
            .foregroundStyle(tone)
            .padding(.horizontal, UIScale.pt(7))
            .padding(.vertical, UIScale.pt(2))
            .background(tone.opacity(0.14), in: Capsule())
    }

    private var observationsCard: some View {
        SkinCard(title: "Observed activity", dark: dark, fill: true) {
            if model.observations.isEmpty {
                emptyText("No observations yet. Sync GitHub from Settings.")
            } else {
                VStack(alignment: .leading, spacing: UIScale.pt(6)) {
                    ForEach(model.observations, id: \.id) { observation in
                        HStack(spacing: UIScale.pt(7)) {
                            Text(observation.kind)
                                .font(.system(size: UIScale.pt(10)))
                                .foregroundStyle(DashSkin.inkFaint(dark))
                                .frame(width: UIScale.pt(74), alignment: .leading)
                            Text(observation.summary)
                                .font(.system(size: UIScale.pt(12)))
                                .foregroundStyle(DashSkin.ink(dark))
                                .lineLimit(1)
                            Spacer(minLength: 0)
                            Text(String(observation.observedAt.prefix(10)))
                                .font(.system(size: UIScale.pt(10.5)))
                                .monospacedDigit()
                                .foregroundStyle(DashSkin.inkFaint(dark))
                        }
                    }
                }
            }
        }
    }

    private var nightlyCard: some View {
        SkinCard(
            title: "Nightly run",
            note: model.runningNightly ? "running…" : "02:00 on the companion",
            dark: dark, fill: true
        ) {
            VStack(alignment: .leading, spacing: UIScale.pt(8)) {
                Button(model.runningNightly ? "Running the pipeline…" : "Run now") {
                    Task { await model.runNightly() }
                }
                .disabled(model.runningNightly)
                if let run = model.runs.first {
                    Text(runSummary(run))
                        .font(.system(size: UIScale.pt(11.5)))
                        .foregroundStyle(DashSkin.inkSoft(dark))
                    stepChips(run)
                } else {
                    emptyText("No runs yet. The scheduler fires at 02:00, or run it now.")
                }
            }
        }
    }

    private func runSummary(_ run: CompanionRun) -> String {
        let when = String(run.startedAt.prefix(16)).replacingOccurrences(of: "T", with: " ")
        return run.ok ? "Last run \(when) — all steps green" : "Last run \(when)"
    }

    private func stepChips(_ run: CompanionRun) -> some View {
        FlowChips(spacing: UIScale.pt(6)) {
            ForEach(Array(run.steps.enumerated()), id: \.offset) { _, step in
                HStack(spacing: UIScale.pt(4)) {
                    Image(systemName: step.ok ? "checkmark" : "xmark")
                        .font(.system(size: UIScale.pt(8.5), weight: .bold))
                        .foregroundStyle(step.ok ? .green : .red)
                    Text(step.name)
                        .font(.system(size: UIScale.pt(10.5)))
                        .foregroundStyle(DashSkin.inkSoft(dark))
                }
                .padding(.horizontal, UIScale.pt(8))
                .padding(.vertical, UIScale.pt(3))
                .overlay {
                    RoundedRectangle(cornerRadius: UIScale.pt(7))
                        .strokeBorder(DashSkin.line(dark))
                }
            }
        }
    }

    private func emptyText(_ message: String) -> some View {
        Text(message)
            .font(.system(size: UIScale.pt(12)))
            .foregroundStyle(DashSkin.inkFaint(dark))
    }
}
