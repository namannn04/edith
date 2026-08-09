import AppKit
import EdithKit
import SwiftUI
import UniformTypeIdentifiers

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
    @Published var question = ""
    @Published private(set) var asking = false
    @Published private(set) var askAnswer: CompanionAskOutcome?
    @Published private(set) var ingesting = false
    @Published private(set) var ingestSummary: String?
    @Published private(set) var beliefs: [CompanionBelief] = []

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
            beliefs = try await client.beliefs(limit: 8)
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

    func ask() async {
        let trimmed = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !asking else { return }
        asking = true
        defer { asking = false }
        do {
            askAnswer = try await client.ask(question: trimmed)
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    func ingest(urls: [URL]) async {
        guard !urls.isEmpty, !ingesting else { return }
        ingesting = true
        defer { ingesting = false }
        var ingested = 0
        var duplicates = 0
        var skipped = 0
        do {
            let client = client
            for url in urls {
                let markdown = try CompanionScan.markdownFiles(at: url)
                let audio = try CompanionScan.audioFiles(at: url)
                skipped += markdown.skipped.count + audio.skipped.count
                if !markdown.files.isEmpty {
                    let outcomes = try await client.ingest(files: markdown.files)
                    ingested += outcomes.filter { $0.status == "ingested" }.count
                    duplicates += outcomes.filter { $0.status == "duplicate" }.count
                }
                for file in audio.files {
                    let outcome = try await client.ingestAudio(
                        name: file.name, data: file.data, mtime: file.mtime)
                    if outcome.status == "ingested" { ingested += 1 } else { duplicates += 1 }
                }
            }
            ingestSummary =
                "\(ingested) ingested, \(duplicates) duplicates, \(skipped) skipped"
            error = nil
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
                    askCard
                    searchCard
                    if model.hits.isEmpty {
                        beliefsCard
                        episodesCard
                        observationsCard
                    }
                }
                .pageContent(compact)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DashSkin.paper(dark))
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            Task {
                var urls: [URL] = []
                for provider in providers {
                    if let url = try? await provider.loadItem(
                        forTypeIdentifier: UTType.fileURL.identifier) as? URL
                    {
                        urls.append(url)
                    } else if let data = try? await provider.loadItem(
                        forTypeIdentifier: UTType.fileURL.identifier) as? Data,
                        let url = URL(dataRepresentation: data, relativeTo: nil)
                    {
                        urls.append(url)
                    }
                }
                await model.ingest(urls: urls)
            }
            return true
        }
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
                    if let summary = model.ingestSummary {
                        Text(summary)
                            .font(.system(size: UIScale.pt(11)))
                            .foregroundStyle(DashSkin.inkFaint(dark))
                    }
                    Button(model.ingesting ? "Ingesting…" : "Ingest Files…") {
                        pickAndIngest()
                    }
                    .disabled(model.ingesting)
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

    private func pickAndIngest() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.message = "Pick Markdown notes, voice recordings, or folders of them"
        guard panel.runModal() == .OK else { return }
        let urls = panel.urls
        Task { await model.ingest(urls: urls) }
    }

    private var askCard: some View {
        SkinCard(title: "Ask", dark: dark) {
            VStack(alignment: .leading, spacing: UIScale.pt(10)) {
                HStack(spacing: UIScale.pt(8)) {
                    EdithTextField(
                        placeholder: "Ask about your own life", text: $model.question,
                        icon: "bubble.left")
                    Button(model.asking ? "Thinking…" : "Ask") {
                        Task { await model.ask() }
                    }
                    .disabled(model.asking)
                }
                if let outcome = model.askAnswer {
                    Text(outcome.answer)
                        .font(.system(size: UIScale.pt(13)))
                        .foregroundStyle(DashSkin.ink(dark))
                        .textSelection(.enabled)
                    ForEach(Array(outcome.citations.enumerated()), id: \.offset) {
                        index, citation in
                        VStack(alignment: .leading, spacing: UIScale.pt(2)) {
                            Text(
                                "[\(index + 1)] \(citation.title)  \(citation.occurredAt)  "
                                    + (citation.support == "inference"
                                        ? "reading between the lines"
                                        : citation.support))
                                .font(.system(size: UIScale.pt(11), weight: .semibold))
                                .foregroundStyle(DashSkin.inkFaint(dark))
                            if !citation.quote.isEmpty {
                                Text("\u{201C}\(citation.quote)\u{201D}")
                                    .font(.system(size: UIScale.pt(11.5)))
                                    .foregroundStyle(DashSkin.inkFaint(dark))
                                    .textSelection(.enabled)
                            }
                        }
                        .padding(.leading, UIScale.pt(8))
                    }
                    Text(outcome.model)
                        .font(.system(size: UIScale.pt(10)))
                        .foregroundStyle(DashSkin.inkFaint(dark))
                }
            }
        }
    }

    private var beliefsCard: some View {
        SkinCard(title: "Beliefs", dark: dark) {
            if model.beliefs.isEmpty {
                Text("Nothing concluded yet. The nightly run forms beliefs from episodes.")
                    .font(.system(size: UIScale.pt(12)))
                    .foregroundStyle(DashSkin.inkFaint(dark))
            } else {
                VStack(alignment: .leading, spacing: UIScale.pt(6)) {
                    ForEach(model.beliefs, id: \.id) { belief in
                        HStack(alignment: .firstTextBaseline) {
                            Text(belief.kind)
                                .font(.system(size: UIScale.pt(10.5)))
                                .foregroundStyle(DashSkin.inkFaint(dark))
                            Text(belief.statement)
                                .font(.system(size: UIScale.pt(12.5)))
                                .foregroundStyle(DashSkin.ink(dark))
                            Spacer()
                            Text("\(Int(belief.confidence * 100))%")
                                .font(.system(size: UIScale.pt(11)))
                                .foregroundStyle(DashSkin.inkFaint(dark))
                        }
                    }
                }
            }
        }
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
