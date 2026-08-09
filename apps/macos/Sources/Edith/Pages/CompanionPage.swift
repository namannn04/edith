import EdithKit
import SwiftUI

@MainActor
final class CompanionModel: ObservableObject {
    @Published private(set) var status: CompanionStatus?
    @Published private(set) var checks: [CompanionCheck] = []
    @Published private(set) var episodes: [CompanionEpisode] = []
    @Published private(set) var observations: [CompanionObservation] = []
    @Published private(set) var hits: [CompanionSearchHit] = []
    @Published private(set) var error: String?
    @Published private(set) var syncing = false
    @Published var query = ""

    private var client: CompanionClient {
        CompanionClient(baseURL: CompanionClient.endpoint(override: nil))
    }

    func refresh() async {
        do {
            let client = client
            let health = try await client.health()
            checks = health.checks
            status = try await client.status()
            episodes = try await client.episodes(limit: 12)
            observations = try await client.observations(limit: 12, kind: nil)
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    func search() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            hits = []
            return
        }
        do {
            hits = try await client.search(query: trimmed, k: 10)
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    func syncGithub() async {
        syncing = true
        defer { syncing = false }
        do {
            _ = try await client.syncGithub()
            await refresh()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

struct CompanionPage: View {
    @StateObject private var model = CompanionModel()
    @Environment(\.colorScheme) private var scheme
    @Environment(\.compactLayout) private var compact

    private var dark: Bool { scheme == .dark }

    var body: some View {
        VStack(spacing: UIScale.pt(0)) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: UIScale.pt(16)) {
                    if let error = model.error {
                        errorBanner(error)
                    }
                    searchCard
                    if model.hits.isEmpty {
                        episodesCard
                        observationsCard
                    }
                }
                .pageContent(compact)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DashSkin.paper(dark))
        .task {
            while !Task.isCancelled {
                await model.refresh()
                try? await Task.sleep(for: .seconds(20))
            }
        }
        .onChange(of: model.query) {
            Task { await model.search() }
        }
    }

    private var header: some View {
        PageHeader(
            "Companion",
            trailing: {
                HStack(spacing: UIScale.pt(10)) {
                    healthDot
                    Button(model.syncing ? "Syncing…" : "Sync GitHub") {
                        Task { await model.syncGithub() }
                    }
                    .disabled(model.syncing)
                }
            },
            accessory: {
                if let status = model.status {
                    Text(summaryLine(status))
                        .font(.system(size: UIScale.pt(12)))
                        .foregroundStyle(DashSkin.inkFaint(dark))
                }
            }
        )
        .pageGutter(compact)
    }

    private var healthDot: some View {
        let healthy = !model.checks.isEmpty && model.checks.allSatisfy(\.ok)
        return HStack(spacing: UIScale.pt(5)) {
            Circle()
                .fill(healthy ? Color.green : Color.orange)
                .frame(width: UIScale.pt(8), height: UIScale.pt(8))
            Text(healthy ? "healthy" : "degraded")
                .font(.system(size: UIScale.pt(11.5)))
                .foregroundStyle(DashSkin.inkFaint(dark))
        }
        .help(model.checks.map { "\($0.name): \($0.detail)" }.joined(separator: "\n"))
    }

    private func summaryLine(_ status: CompanionStatus) -> String {
        "\(status.episodes) episodes, \(status.chunks) chunks indexed, "
            + "\(status.observations) observations"
    }

    private func errorBanner(_ message: String) -> some View {
        Text(message)
            .font(.system(size: UIScale.pt(12)))
            .foregroundStyle(.orange)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var searchCard: some View {
        SkinCard(title: "Search", dark: dark) {
            VStack(alignment: .leading, spacing: UIScale.pt(10)) {
                SearchField(placeholder: "Search your memory", text: $model.query)
                ForEach(model.hits, id: \.chunkId) { hit in
                    VStack(alignment: .leading, spacing: UIScale.pt(3)) {
                        HStack {
                            Text(hit.title)
                                .font(.system(size: UIScale.pt(12.5), weight: .semibold))
                                .foregroundStyle(DashSkin.ink(dark))
                            Spacer()
                            Text(hit.occurredAt)
                                .font(.system(size: UIScale.pt(11)))
                                .foregroundStyle(DashSkin.inkFaint(dark))
                        }
                        Text(hit.snippet)
                            .font(.system(size: UIScale.pt(11.5)))
                            .foregroundStyle(DashSkin.inkFaint(dark))
                            .lineLimit(3)
                    }
                    .padding(.vertical, UIScale.pt(3))
                }
            }
        }
    }

    private var episodesCard: some View {
        SkinCard(title: "Recent episodes", dark: dark) {
            if model.episodes.isEmpty {
                Text("Nothing ingested yet. Run `ed companion ingest <folder>`.")
                    .font(.system(size: UIScale.pt(12)))
                    .foregroundStyle(DashSkin.inkFaint(dark))
            } else {
                VStack(alignment: .leading, spacing: UIScale.pt(6)) {
                    ForEach(model.episodes, id: \.id) { episode in
                        HStack {
                            Text(episode.title)
                                .font(.system(size: UIScale.pt(12.5)))
                                .foregroundStyle(DashSkin.ink(dark))
                                .lineLimit(1)
                            Text(episode.kind)
                                .font(.system(size: UIScale.pt(10.5)))
                                .foregroundStyle(DashSkin.inkFaint(dark))
                            Spacer()
                            Text(episode.occurredAt)
                                .font(.system(size: UIScale.pt(11)))
                                .foregroundStyle(DashSkin.inkFaint(dark))
                        }
                    }
                }
            }
        }
    }

    private var observationsCard: some View {
        SkinCard(title: "Observed activity", dark: dark) {
            if model.observations.isEmpty {
                Text("No observations yet. Sync GitHub above.")
                    .font(.system(size: UIScale.pt(12)))
                    .foregroundStyle(DashSkin.inkFaint(dark))
            } else {
                VStack(alignment: .leading, spacing: UIScale.pt(6)) {
                    ForEach(model.observations, id: \.id) { observation in
                        HStack {
                            Text(observation.kind)
                                .font(.system(size: UIScale.pt(10.5)))
                                .foregroundStyle(DashSkin.inkFaint(dark))
                            Text(observation.summary)
                                .font(.system(size: UIScale.pt(12)))
                                .foregroundStyle(DashSkin.ink(dark))
                                .lineLimit(1)
                            Spacer()
                            Text(observation.observedAt)
                                .font(.system(size: UIScale.pt(11)))
                                .foregroundStyle(DashSkin.inkFaint(dark))
                        }
                    }
                }
            }
        }
    }
}
