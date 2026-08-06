import Foundation

@MainActor
public final class MachineSession: ObservableObject {
    public let machine: Machine
    public nonisolated var id: UUID { machine.id }

    @Published public private(set) var state: MachineConnectionState = .disconnected
    @Published public private(set) var hello: MachineHello?
    @Published public private(set) var sample: MachineSample?
    @Published public private(set) var slow: MachineSlow?
    @Published public private(set) var cpuHistory: [Double] = []
    @Published public private(set) var memHistory: [Double] = []
    @Published public private(set) var netRxHistory: [Double] = []
    @Published public private(set) var netTxHistory: [Double] = []
    @Published public private(set) var diskReadHistory: [Double] = []
    @Published public private(set) var diskWriteHistory: [Double] = []
    @Published public private(set) var docker = DockerAvailability(status: .unknown)
    @Published public private(set) var containersLoaded = false
    @Published public private(set) var containers: [DockerContainer] = []
    @Published public private(set) var images: [DockerImage] = []
    @Published public private(set) var volumes: [DockerVolume] = []
    @Published public private(set) var diskUsage: [DockerDiskUsage] = []
    @Published public private(set) var networks: [DockerNetwork] = []
    @Published public private(set) var services: [SystemdService] = []
    @Published public private(set) var facts = MachineSessionSummary()
    @Published public private(set) var activeForwards: Set<UUID> = []
    @Published public private(set) var isLocal: Bool

    public static let historyLength = 60

    private let connection: SSHConnection?
    private let localSampler: LocalMachineSampler?
    private var metricsStream: SSHLineStream?
    private var metricsTask: Task<Void, Never>?
    private var dockerTask: Task<Void, Never>?
    private var latencyTask: Task<Void, Never>?
    private var localTask: Task<Void, Never>?

    public init(machine: Machine, local: Bool = false) {
        self.machine = machine
        isLocal = local
        connection = local ? nil : SSHConnection(machine: machine)
        localSampler = local ? LocalMachineSampler() : nil
    }

    public var connectionRef: SSHConnection? { connection }

    public func start() {
        guard !state.isConnected, !state.isBusy else { return }
        if isLocal {
            startLocal()
            return
        }
        state = .connecting
        metricsTask = Task { [weak self] in
            guard let self, let connection else { return }
            do {
                try await connection.connect()
                guard !Task.isCancelled else { return }
                state = .connected(latencyMillis: nil)
                startMetricsStream()
                startDockerPolling()
                startLatencyProbe()
                await loadFacts()
            } catch {
                guard !Task.isCancelled else { return }
                state = .failed(message: error.localizedDescription)
            }
        }
    }

    public func stop() {
        metricsTask?.cancel()
        metricsTask = nil
        dockerTask?.cancel()
        dockerTask = nil
        latencyTask?.cancel()
        latencyTask = nil
        localTask?.cancel()
        localTask = nil
        metricsStream?.cancel()
        metricsStream = nil
        let connection = connection
        Task { await connection?.disconnect() }
        state = .disconnected
    }

    public func retry() {
        stop()
        start()
    }

    private func startLocal() {
        state = .connected(latencyMillis: 0)
        hello = localSampler?.hello()
        localTask = Task { [weak self] in
            var tick = 0
            while !Task.isCancelled {
                guard let self, let sampler = localSampler else { return }
                let next = await sampler.sample()
                guard !Task.isCancelled else { return }
                apply(sample: next)
                if tick % 15 == 0 {
                    slow = sampler.slow()
                }
                tick += 1
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }

    private func startMetricsStream() {
        guard let connection, let script = MachineCollector.script() else { return }
        let process = connection.streamProcess(command: MachineCollector.streamCommand)
        let stream = SSHLineStream(
            process: process, stdinData: script,
            onLine: { [weak self] line, isStderr in
                guard !isStderr, let record = MachineMetricsDecoder.decode(line: line) else {
                    return
                }
                Task { @MainActor in self?.apply(record: record) }
            },
            onExit: { [weak self] _ in
                Task { @MainActor in self?.handleMetricsStreamEnded() }
            })
        try? stream.start()
        metricsStream = stream
    }

    private func handleMetricsStreamEnded() {
        guard state.isConnected else { return }
        metricsStream = nil
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard let self, state.isConnected, metricsStream == nil else { return }
            startMetricsStream()
        }
    }

    private func apply(record: MachineMetricRecord) {
        switch record {
        case let .hello(value): hello = value
        case let .sample(value): apply(sample: value)
        case let .slow(value): slow = value
        }
    }

    private func apply(sample value: MachineSample) {
        sample = value
        cpuHistory = Self.appending(value.cpu.total, to: cpuHistory)
        memHistory = Self.appending(value.mem.usedPercent, to: memHistory)
        netRxHistory = Self.appending(value.net.rxBps, to: netRxHistory)
        netTxHistory = Self.appending(value.net.txBps, to: netTxHistory)
        diskReadHistory = Self.appending(value.disk.readBps, to: diskReadHistory)
        diskWriteHistory = Self.appending(value.disk.writeBps, to: diskWriteHistory)
    }

    public static func appending(_ value: Double, to history: [Double]) -> [Double] {
        guard !history.isEmpty else {
            return Array(repeating: value, count: historyLength)
        }
        var next = history
        next.append(value)
        if next.count > historyLength {
            next.removeFirst(next.count - historyLength)
        }
        return next
    }

    private func startLatencyProbe() {
        latencyTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self, let connection else { return }
                let alive = await connection.masterIsAlive()
                guard !Task.isCancelled else { return }
                if alive {
                    let latency = await connection.latencyMillis()
                    guard !Task.isCancelled else { return }
                    if state.isConnected {
                        state = .connected(latencyMillis: latency)
                    }
                } else if state.isConnected {
                    state = .failed(message: "The connection dropped.")
                    metricsStream?.cancel()
                    metricsStream = nil
                }
                try? await Task.sleep(for: .seconds(10))
            }
        }
    }

    public func refreshDockerNow() {
        Task { await refreshDocker() }
    }

    private func startDockerPolling() {
        dockerTask = Task { [weak self] in
            guard let self, let connection else { return }
            let version = try? await connection.run(DockerCommands.version(), timeout: 20)
            guard !Task.isCancelled else { return }
            var availability = DockerParsing.availability(
                versionOutput: version?.stdoutText ?? "", versionStderr: version?.stderrText ?? "",
                status: version?.status ?? 1)
            if case let .available(serverVersion, _) = availability.status {
                let compose = try? await connection.run(
                    DockerCommands.composeVersion(), timeout: 15)
                availability = DockerAvailability(
                    status: .available(
                        serverVersion: serverVersion, hasCompose: compose?.succeeded == true))
            }
            guard !Task.isCancelled else { return }
            docker = availability
            guard availability.isAvailable else { return }
            await refreshImagesAndVolumes()
            while !Task.isCancelled {
                await refreshDocker()
                try? await Task.sleep(for: .seconds(4))
            }
        }
    }

    private func refreshDocker() async {
        guard let connection, docker.isAvailable else { return }
        guard
            let result = try? await connection.run(
                DockerCommands.containersWithStats(), timeout: 30), result.succeeded
        else { return }
        let sections = result.stdoutText.components(separatedBy: DockerCommands.listSeparator)
        let parsed = DockerParsing.containers(psOutput: sections.first ?? "")
        containers =
            sections.count > 1
            ? DockerParsing.applyStats(sections[1], to: parsed) : parsed
        containersLoaded = true
    }

    public func refreshImagesAndVolumes() async {
        guard let connection, docker.isAvailable else { return }
        async let imagesResult = try? connection.run(DockerCommands.images(), timeout: 30)
        async let volumesResult = try? connection.run(DockerCommands.volumes(), timeout: 30)
        async let usageResult = try? connection.run(DockerCommands.diskUsage(), timeout: 30)
        async let verboseResult = try? connection.run(
            DockerCommands.diskUsageVerbose(), timeout: 60)
        let (imagesOut, volumesOut, usageOut, verboseOut) = await (
            imagesResult, volumesResult, usageResult, verboseResult
        )
        images = DockerParsing.images(imagesOut?.stdoutText ?? "")
        if let networksOut = try? await connection.run(DockerCommands.networks(), timeout: 20) {
            networks = DockerParsing.networks(networksOut.stdoutText)
        }
        let details = DockerParsing.volumeDetails(
            systemDFOutput: verboseOut?.stdoutText ?? "")
        volumes = DockerParsing.volumes(volumesOut?.stdoutText ?? "").map { volume in
            var updated = volume
            if let detail = details[volume.name] {
                updated.sizeBytes = detail.0
                updated.containerCount = detail.1
            }
            return updated
        }
        diskUsage = DockerParsing.diskUsage(usageOut?.stdoutText ?? "")
    }

    @discardableResult
    public func runDocker(_ command: String) async -> Result<String, Error> {
        guard let connection else {
            return .failure(
                SSHConnectionError.commandFailed(
                    command: command, status: 1, stderr: "Not connected."))
        }
        do {
            let result = try await connection.run(command, timeout: 120)
            guard result.succeeded else {
                let message = result.stderrText.isEmpty ? result.stdoutText : result.stderrText
                return .failure(
                    SSHConnectionError.commandFailed(
                        command: command, status: result.status, stderr: message))
            }
            await refreshDocker()
            return .success(result.stdoutText)
        } catch {
            return .failure(error)
        }
    }

    public func runCommand(_ command: String, timeout: TimeInterval = 60) async
        -> Result<String, Error>
    {
        guard let connection else {
            return await runLocalCommand(command)
        }
        do {
            let result = try await connection.run(command, timeout: timeout)
            let output = result.stdoutText + result.stderrText
            guard result.succeeded else {
                return .failure(
                    SSHConnectionError.commandFailed(
                        command: command, status: result.status, stderr: output))
            }
            return .success(output)
        } catch {
            return .failure(error)
        }
    }

    private func runLocalCommand(_ command: String) async -> Result<String, Error> {
        await Task.detached(priority: .userInitiated) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = ["-lc", command]
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            do {
                try process.run()
            } catch {
                return .failure(error)
            }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            let text = String(decoding: data, as: UTF8.self)
            guard process.terminationStatus == 0 else {
                return .failure(
                    SSHConnectionError.commandFailed(
                        command: command, status: process.terminationStatus, stderr: text))
            }
            return .success(text)
        }.value
    }

    public func refreshServices() async {
        guard !isLocal, let connection else { return }
        guard let result = try? await connection.run(ServiceCommands.list(), timeout: 30) else {
            return
        }
        services = ServiceCommands.parse(result.stdoutText)
    }

    private func loadFacts() async {
        guard let connection else { return }
        async let whoResult = try? connection.run(MachineFacts.whoCommand, timeout: 15)
        async let macResult = try? connection.run(MachineFacts.macAddressCommand, timeout: 15)
        async let updatesResult = try? connection.run(MachineFacts.updatesCommand, timeout: 45)
        let (who, mac, updates) = await (whoResult, macResult, updatesResult)
        facts = MachineSessionSummary(
            who: MachineFacts.parseWho(who?.stdoutText ?? ""),
            updatesAvailable: MachineFacts.parseUpdates(updates?.stdoutText ?? ""),
            macAddress: MachineFacts.parseMACAddress(mac?.stdoutText ?? ""))
    }

    public func setForward(_ forward: PortForward, active: Bool) async -> String? {
        guard let connection else { return "Not connected." }
        if active {
            do {
                try await connection.addForward(forward)
                activeForwards.insert(forward.id)
                return nil
            } catch {
                return error.localizedDescription
            }
        }
        await connection.cancelForward(forward)
        activeForwards.remove(forward.id)
        return nil
    }

    public func listFiles(path: String) async -> Result<[RemoteFileEntry], Error> {
        if isLocal {
            return .success(Self.listLocalFiles(path: path))
        }
        guard let connection else { return .success([]) }
        do {
            let result = try await connection.run(
                FileListing.command(path: path, showHidden: true), timeout: 45)
            let entries = FileListing.parse(output: result.stdoutText, parent: path)
            if entries.isEmpty, !result.succeeded {
                let message =
                    result.stderrText.isEmpty
                    ? "Could not read that folder." : result.stderrText
                return .failure(
                    SSHConnectionError.commandFailed(
                        command: "list", status: result.status, stderr: message))
            }
            return .success(entries)
        } catch {
            return .failure(error)
        }
    }

    nonisolated static func listLocalFiles(path: String) -> [RemoteFileEntry] {
        let fm = FileManager.default
        let keys: [URLResourceKey] = [
            .isDirectoryKey, .isSymbolicLinkKey, .fileSizeKey, .contentModificationDateKey,
        ]
        guard
            let urls = try? fm.contentsOfDirectory(
                at: URL(fileURLWithPath: path), includingPropertiesForKeys: keys,
                options: [])
        else { return [] }
        let entries = urls.map { url -> RemoteFileEntry in
            let values = try? url.resourceValues(forKeys: Set(keys))
            let kind: FileEntryKind =
                values?.isSymbolicLink == true
                ? .symlink : (values?.isDirectory == true ? .directory : .file)
            return RemoteFileEntry(
                name: url.lastPathComponent, path: url.path, kind: kind,
                sizeBytes: Int64(values?.fileSize ?? 0),
                modified: values?.contentModificationDate)
        }
        return FileListing.sorted(entries)
    }
}
