import Foundation

@MainActor
public final class MachineStore: ObservableObject {
    @Published public private(set) var machines: [Machine] = []
    @Published public private(set) var forwards: [PortForward] = []
    @Published public private(set) var snippets: [CommandSnippet] = []

    private let machinesFile: URL
    private let forwardsFile: URL
    private let snippetsFile: URL

    public init(
        machinesFile: URL = MachinePaths.machinesFile,
        forwardsFile: URL = MachinePaths.forwardsFile,
        snippetsFile: URL = MachinePaths.snippetsFile
    ) {
        self.machinesFile = machinesFile
        self.forwardsFile = forwardsFile
        self.snippetsFile = snippetsFile
        machines = Self.load(machinesFile) ?? []
        forwards = Self.load(forwardsFile) ?? []
        snippets = Self.load(snippetsFile) ?? []
    }

    public func machine(id: UUID) -> Machine? {
        machines.first { $0.id == id }
    }

    public func add(_ machine: Machine) {
        machines.append(machine)
        persistMachines()
    }

    public func update(_ machine: Machine) {
        guard let index = machines.firstIndex(where: { $0.id == machine.id }) else { return }
        machines[index] = machine
        persistMachines()
    }

    public func remove(id: UUID) {
        machines.removeAll { $0.id == id }
        forwards.removeAll { $0.machineID == id }
        snippets.removeAll { $0.machineID == id }
        persistMachines()
        Self.save(forwards, to: forwardsFile)
        Self.save(snippets, to: snippetsFile)
        MachineSecrets.deleteAll(machineID: id)
    }

    public func addForward(_ forward: PortForward) {
        forwards.append(forward)
        Self.save(forwards, to: forwardsFile)
    }

    public func removeForward(id: UUID) {
        forwards.removeAll { $0.id == id }
        Self.save(forwards, to: forwardsFile)
    }

    public func forwards(machineID: UUID) -> [PortForward] {
        forwards.filter { $0.machineID == machineID }
    }

    public func addSnippet(_ snippet: CommandSnippet) {
        snippets.append(snippet)
        Self.save(snippets, to: snippetsFile)
    }

    public func updateSnippet(_ snippet: CommandSnippet) {
        guard let index = snippets.firstIndex(where: { $0.id == snippet.id }) else { return }
        snippets[index] = snippet
        Self.save(snippets, to: snippetsFile)
    }

    public func removeSnippet(id: UUID) {
        snippets.removeAll { $0.id == id }
        Self.save(snippets, to: snippetsFile)
    }

    public func snippets(machineID: UUID) -> [CommandSnippet] {
        snippets.filter { $0.machineID == nil || $0.machineID == machineID }
    }

    private func persistMachines() {
        Self.save(machines, to: machinesFile)
    }

    private static func load<T: Decodable>(_ file: URL) -> T? {
        guard let data = try? Data(contentsOf: file) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(T.self, from: data)
    }

    private static func save<T: Encodable>(_ value: T, to file: URL) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(value) else { return }
        try? FileManager.default.createDirectory(
            at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: file, options: .atomic)
    }
}
