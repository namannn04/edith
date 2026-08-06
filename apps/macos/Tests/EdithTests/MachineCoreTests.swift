import Foundation
import Testing

@testable import EdithKit

@Suite struct ShellQuoteTests {
    @Test func passesSafeStringsThrough() {
        #expect(ShellQuote.quote("docker") == "docker")
        #expect(ShellQuote.quote("/var/run/docker.sock") == "/var/run/docker.sock")
        #expect(ShellQuote.quote("a-b_c.d:e@f%g,h+i=j") == "a-b_c.d:e@f%g,h+i=j")
    }

    @Test func quotesUnsafeStrings() {
        #expect(ShellQuote.quote("hello world") == "'hello world'")
        #expect(ShellQuote.quote("") == "''")
        #expect(ShellQuote.quote("a\"b") == "'a\"b'")
        #expect(ShellQuote.quote("$(rm -rf /)") == "'$(rm -rf /)'")
        #expect(ShellQuote.quote("{{json .}}") == "'{{json .}}'")
    }

    @Test func escapesSingleQuotes() {
        #expect(ShellQuote.quote("it's") == "'it'\\''s'")
    }

    @Test func joinsCommands() {
        #expect(
            ShellQuote.command(["docker", "ps", "-a", "--format", "{{json .}}"])
                == "docker ps -a --format '{{json .}}'")
    }
}

@Suite struct SSHConfigFileTests {
    private let sample = """
        Host *
          ServerAliveInterval 30
          StrictHostKeyChecking accept-new

        # personal laptop
        Host tuf
          HostName 192.168.1.12
          User pulkit
          IdentityFile ~/.ssh/id_ed25519

        Host bastion-*
          User ops

        Host db
          HostName "10.0.0.5"
          Port 2222
          IdentityFile "/Volumes/Ext Drive/keys/db.pem"

        Match host db
          User dbadmin

        Host db
          User firstwins
        """

    @Test func parsesQuotedValuesAndComments() {
        let lines = SSHConfigFile.parseLines("Key \"a value\" other # trailing\n#full comment")
        #expect(
            lines == [SSHConfigFile.ConfigLine(keyword: "Key", arguments: ["a value", "other"])])
    }

    @Test func parsesEqualsSeparator() {
        let lines = SSHConfigFile.parseLines("Port=2200")
        #expect(lines == [SSHConfigFile.ConfigLine(keyword: "Port", arguments: ["2200"])])
    }

    @Test func enumeratesOnlyConcreteAliases() {
        let hosts = SSHConfigFile.concreteHosts(
            configLines: SSHConfigFile.parseLines(sample))
        #expect(hosts.map(\.alias) == ["tuf", "db"])
    }

    @Test func resolvesFirstMatchValues() {
        let hosts = SSHConfigFile.concreteHosts(
            configLines: SSHConfigFile.parseLines(sample))
        let tuf = hosts.first { $0.alias == "tuf" }
        #expect(tuf?.hostName == "192.168.1.12")
        #expect(tuf?.user == "pulkit")
        #expect(tuf?.identityFile?.hasSuffix("/.ssh/id_ed25519") == true)
        #expect(tuf?.identityFile?.hasPrefix("~") == false)
    }

    @Test func handlesQuotedPathsAndPortsAndSkipsMatchBlocks() {
        let hosts = SSHConfigFile.concreteHosts(
            configLines: SSHConfigFile.parseLines(sample))
        let db = hosts.first { $0.alias == "db" }
        #expect(db?.hostName == "10.0.0.5")
        #expect(db?.port == 2222)
        #expect(db?.identityFile == "/Volumes/Ext Drive/keys/db.pem")
        #expect(db?.user == "firstwins")
    }

    @Test func displayTargetFormatsUserHostAndPort() {
        #expect(
            SSHConfigHost(alias: "a", hostName: "h", user: "u", port: 2222).displayTarget
                == "u@h:2222")
        #expect(SSHConfigHost(alias: "a", hostName: "h", port: 22).displayTarget == "h")
        #expect(SSHConfigHost(alias: "a").displayTarget == "a")
    }
}

@Suite struct MachineModelsTests {
    @Test func sshTargetUsesAliasWhenConfigSourced() {
        let machine = Machine(
            name: "Tuf", host: "192.168.1.12", username: "pulkit",
            source: .sshConfigAlias("tuf"))
        #expect(machine.sshTarget == "tuf")
    }

    @Test func sshTargetCombinesUserAndHost() {
        #expect(Machine(name: "A", host: "h", username: "u").sshTarget == "u@h")
        #expect(Machine(name: "A", host: "h").sshTarget == "h")
    }

    @Test func machineRoundTripsThroughCodable() throws {
        let machine = Machine(
            name: "Tuf", host: "192.168.1.12", port: 2222, username: "pulkit",
            auth: .keyFile(path: "/tmp/key", hasPassphrase: true),
            source: .sshConfigAlias("tuf"), wakeMACAddress: "aa:bb:cc:dd:ee:ff",
            createdAt: Date(timeIntervalSince1970: 1_754_000_000))
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(
            Machine.self, from: encoder.encode(machine))
        #expect(decoded == machine)
    }

    @Test func askpassUsage() {
        #expect(MachineAuth.password.usesAskpass)
        #expect(MachineAuth.keyFile(path: "/k", hasPassphrase: true).usesAskpass)
        #expect(!MachineAuth.keyFile(path: "/k", hasPassphrase: false).usesAskpass)
        #expect(!MachineAuth.agent.usesAskpass)
    }

    @Test func forwardSpecTargetsLoopback() {
        let forward = PortForward(
            machineID: UUID(), localPort: 8080, remoteHost: "localhost", remotePort: 3000)
        #expect(forward.forwardSpec == "127.0.0.1:8080:localhost:3000")
    }
}

@Suite @MainActor struct MachineStoreTests {
    private func temporaryStore() -> (MachineStore, URL) {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("MachineStoreTests.\(UUID().uuidString)")
        let store = MachineStore(
            machinesFile: root.appendingPathComponent("machines.json"),
            forwardsFile: root.appendingPathComponent("forwards.json"),
            snippetsFile: root.appendingPathComponent("snippets.json"))
        return (store, root)
    }

    @Test func persistsMachinesAcrossInstances() {
        let (store, root) = temporaryStore()
        defer { try? FileManager.default.removeItem(at: root) }
        let machine = Machine(
            name: "Tuf", host: "192.168.1.12", username: "pulkit",
            createdAt: Date(timeIntervalSince1970: 1_754_000_000))
        store.add(machine)

        let reloaded = MachineStore(
            machinesFile: root.appendingPathComponent("machines.json"),
            forwardsFile: root.appendingPathComponent("forwards.json"),
            snippetsFile: root.appendingPathComponent("snippets.json"))
        #expect(reloaded.machines == [machine])
    }

    @Test func updateReplacesAndRemoveDeletesRelatedRecords() {
        let (store, root) = temporaryStore()
        defer { try? FileManager.default.removeItem(at: root) }
        var machine = Machine(name: "Tuf", host: "192.168.1.12")
        store.add(machine)
        machine.name = "Renamed"
        store.update(machine)
        #expect(store.machines.first?.name == "Renamed")

        store.addForward(PortForward(machineID: machine.id, localPort: 8080, remotePort: 80))
        store.addSnippet(CommandSnippet(machineID: machine.id, title: "T", command: "uptime"))
        store.remove(id: machine.id)
        #expect(store.machines.isEmpty)
        #expect(store.forwards.isEmpty)
        #expect(store.snippets.isEmpty)
    }

    @Test func snippetsIncludeGlobalOnes() {
        let (store, root) = temporaryStore()
        defer { try? FileManager.default.removeItem(at: root) }
        let machineID = UUID()
        store.addSnippet(CommandSnippet(machineID: nil, title: "G", command: "uptime"))
        store.addSnippet(CommandSnippet(machineID: machineID, title: "M", command: "df"))
        store.addSnippet(CommandSnippet(machineID: UUID(), title: "O", command: "ls"))
        #expect(store.snippets(machineID: machineID).map(\.title) == ["G", "M"])
    }
}

@Suite struct MetricsDecoderTests {
    @Test func ignoresLinesWithoutSentinel() {
        #expect(MachineMetricsDecoder.decode(line: "motd banner text") == nil)
        #expect(MachineMetricsDecoder.decode(line: "{\"t\":\"hello\"}") == nil)
    }

    @Test func decodesHello() {
        let line =
            "@EDITH@{\"t\":\"hello\",\"v\":1,\"os\":\"Ubuntu 24.04\",\"osID\":\"ubuntu\","
            + "\"kernel\":\"6.8.0\",\"arch\":\"x86_64\",\"host\":\"tuf\",\"cpuModel\":\"AMD\","
            + "\"cores\":16,\"memTotalKB\":16000000,\"virtual\":false}"
        guard case let .hello(hello)? = MachineMetricsDecoder.decode(line: line) else {
            Issue.record("expected hello record")
            return
        }
        #expect(hello.os == "Ubuntu 24.04")
        #expect(hello.cores == 16)
        #expect(!hello.virtual)
    }

    @Test func decodesSample() {
        let line =
            "@EDITH@{\"t\":\"sample\",\"ts\":1754000000,\"dt\":2.00,"
            + "\"cpu\":{\"total\":12.5,\"steal\":0.0,\"cores\":[10.0,15.0]},"
            + "\"mem\":{\"totalKB\":16000000,\"availKB\":8000000,\"usedKB\":8000000,"
            + "\"buffcacheKB\":2000000,\"swapTotalKB\":1000000,\"swapUsedKB\":0},"
            + "\"load\":[0.52,0.40,0.31],\"tasks\":{\"runnable\":2,\"total\":345},"
            + "\"uptime\":86400,"
            + "\"disk\":{\"devices\":[{\"n\":\"nvme0n1\",\"readBps\":1024,\"writeBps\":2048,"
            + "\"busy\":3.5}],\"readBps\":1024,\"writeBps\":2048},"
            + "\"net\":{\"ifaces\":[{\"n\":\"wlan0\",\"rxBps\":5000,\"txBps\":900,"
            + "\"virtual\":false}],\"rxBps\":5000,\"txBps\":900},"
            + "\"procs\":[{\"pid\":1234,\"user\":\"pulkit\",\"cpu\":42.0,\"mem\":1.5,"
            + "\"rssKB\":245760,\"name\":\"node\",\"cmd\":\"node server.js\"}]}"
        guard case let .sample(sample)? = MachineMetricsDecoder.decode(line: line) else {
            Issue.record("expected sample record")
            return
        }
        #expect(sample.cpu.total == 12.5)
        #expect(sample.cpu.cores == [10.0, 15.0])
        #expect(sample.mem.usedPercent == 50.0)
        #expect(sample.load == [0.52, 0.40, 0.31])
        #expect(sample.disk.devices.first?.n == "nvme0n1")
        #expect(sample.net.rxBps == 5000)
        #expect(sample.procs.first?.name == "node")
    }

    @Test func decodesSlowWithOptionalSections() {
        let base =
            "@EDITH@{\"t\":\"slow\",\"disks\":[{\"fs\":\"/dev/nvme0n1p2\",\"mount\":\"/\","
            + "\"totalKB\":500000000,\"usedKB\":250000000,\"availKB\":225000000}],"
            + "\"temps\":[{\"label\":\"x86_pkg_temp\",\"c\":54.0}]}"
        guard case let .slow(slow)? = MachineMetricsDecoder.decode(line: base) else {
            Issue.record("expected slow record")
            return
        }
        #expect(slow.disks.first?.usedPercent == 50.0)
        #expect(slow.battery == nil)
        #expect(slow.gpu == nil)

        let full =
            String(base.dropLast())
            + ",\"battery\":{\"percent\":87,\"status\":\"Discharging\"},"
            + "\"gpu\":{\"name\":\"RTX 4060\",\"util\":11,\"memUsedMB\":800,"
            + "\"memTotalMB\":8188,\"temp\":45}}"
        guard case let .slow(rich)? = MachineMetricsDecoder.decode(line: String(full)) else {
            Issue.record("expected slow record")
            return
        }
        #expect(rich.battery?.percent == 87)
        #expect(rich.gpu?.name == "RTX 4060")
    }

    @Test func collectorScriptResourceExists() {
        let script = MachineCollector.script()
        #expect(script != nil)
        let text = String(decoding: script ?? Data(), as: UTF8.self)
        #expect(text.hasPrefix("#!/bin/sh"))
        #expect(text.contains("@EDITH@"))
    }
}

@Suite struct AskpassEntryTests {
    @Test func detectsConfirmationPrompts() {
        #expect(AskpassEntry.isConfirmationPrompt("Are you sure you want to continue?"))
        #expect(
            AskpassEntry.isConfirmationPrompt(
                "The authenticity of host 'x' can't be established. (yes/no/[fingerprint])"))
        #expect(!AskpassEntry.isConfirmationPrompt("pulkit@tuf's password:"))
    }

    @Test func skipsWhenNoAccountRequested() {
        #expect(!AskpassEntry.runIfRequested(arguments: ["edith"], environment: [:]))
    }
}

@Suite struct SSHConnectionArgumentTests {
    private let aliasMachine = Machine(
        name: "Tuf", host: "192.168.1.12", username: "pulkit", source: .sshConfigAlias("tuf"))

    @Test func masterBindsTheControlSocket() async {
        let connection = SSHConnection(machine: aliasMachine)
        let arguments = connection.masterArguments()
        let socketIndex = arguments.firstIndex(of: "-S")
        #expect(socketIndex != nil)
        #expect(arguments[(socketIndex ?? 0) + 1] == connection.controlSocketPath)
        #expect(arguments.contains("-M"))
        #expect(arguments.last == "tuf")
    }

    @Test func execAndTerminalReuseTheSameSocket() async {
        let connection = SSHConnection(machine: aliasMachine)
        let socket = connection.controlSocketPath
        #expect(connection.execArguments(command: "uptime").contains(socket))
        #expect(connection.terminalArguments().contains(socket))
        #expect(connection.terminalArguments().contains("-tt"))
        #expect(connection.execArguments(command: "uptime").last == "uptime")
    }

    @Test func knownHostsPathsAreQuotedForSpaces() async {
        let connection = SSHConnection(machine: aliasMachine)
        let arguments = connection.masterArguments()
        guard let option = arguments.first(where: { $0.hasPrefix("UserKnownHostsFile=") }) else {
            Issue.record("expected a UserKnownHostsFile option")
            return
        }
        #expect(option.contains("\""))
        let quoted = option.dropFirst("UserKnownHostsFile=".count)
        #expect(quoted.filter { $0 == "\"" }.count == 4)
    }

    @Test func manualMachinesCarryPortAndIdentity() async {
        let machine = Machine(
            name: "Box", host: "10.0.0.5", port: 2222, username: "root",
            auth: .keyFile(path: "/tmp/key", hasPassphrase: false))
        let arguments = SSHConnection(machine: machine).masterArguments()
        #expect(arguments.contains("2222"))
        #expect(arguments.contains("/tmp/key"))
        #expect(arguments.contains("IdentitiesOnly=yes"))
        #expect(arguments.last == "root@10.0.0.5")
    }

    @Test func passwordMachinesDisablePublicKeyAuth() async {
        let machine = Machine(name: "Box", host: "10.0.0.5", username: "root", auth: .password)
        let arguments = SSHConnection(machine: machine).masterArguments()
        #expect(arguments.contains("PubkeyAuthentication=no"))
        #expect(arguments.contains("NumberOfPasswordPrompts=1"))
    }
}

@Suite struct SSHConnectionErrorTests {
    @Test func mapsCommonFailuresToFriendlyMessages() {
        #expect(
            SSHConnection.friendlyConnectError("pulkit@host: Permission denied (publickey).")
                .contains("Authentication failed"))
        #expect(
            SSHConnection.friendlyConnectError(
                "@@@ WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED! @@@"
            ).contains("host key changed"))
        #expect(
            SSHConnection.friendlyConnectError("ssh: connect to host x port 22: Connection refused")
                .contains("refused"))
        #expect(
            SSHConnection.friendlyConnectError("ssh: Could not resolve hostname zzz")
                .contains("resolve"))
        #expect(SSHConnection.friendlyConnectError("") == "Connection failed.")
    }
}
