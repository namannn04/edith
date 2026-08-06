import Foundation
import Testing

@testable import EdithCLI
@testable import EdithKit

@Suite struct CLIMachineTests {
    static let alias = Machine(
        id: UUID(uuidString: "4303DCF1-52D8-4075-AE9B-C2FD86D3821A")!, name: "Asus TUF 7",
        host: "192.168.1.12", username: "pulkit", source: .sshConfigAlias("tuf"))
    static let manual = Machine(name: "Builder", host: "10.0.0.9", port: 2222, username: "root")
    static let all = [alias, manual]

    @Test func namesIncludeBothTheLabelAndTheSSHAlias() {
        #expect(MachineDirectory.names(from: Self.all) == ["Asus TUF 7", "tuf", "Builder"])
    }

    @Test func resolutionAcceptsNameAliasAndIdentifier() throws {
        let byName = try MachineDirectory.resolve("asus tuf 7", in: Self.all)
        let byAlias = try MachineDirectory.resolve("tuf", in: Self.all)
        let byID = try MachineDirectory.resolve(Self.alias.id.uuidString, in: Self.all)
        #expect(byName.id == Self.alias.id)
        #expect(byAlias.id == Self.alias.id)
        #expect(byID.id == Self.alias.id)
    }

    @Test func aUniquePrefixResolves() throws {
        let resolved = try MachineDirectory.resolve("buil", in: Self.all)
        #expect(resolved.id == Self.manual.id)
    }

    @Test func anAmbiguousPrefixFailsLoudly() {
        let machines = [
            Machine(name: "build-a", host: "a"), Machine(name: "build-b", host: "b"),
        ]
        #expect(throws: CLIFailure.self) {
            try MachineDirectory.resolve("build", in: machines)
        }
    }

    @Test func anUnknownNameIsNotFoundRatherThanAGenericFailure() {
        do {
            _ = try MachineDirectory.resolve("nope", in: Self.all)
            Issue.record("resolution should have failed")
        } catch let failure as CLIFailure {
            #expect(failure.kind == .notFound)
        } catch {
            Issue.record("unexpected error \(error)")
        }
    }

    @Test func anEmptyMachineListExplainsHowToAddOne() {
        do {
            _ = try MachineDirectory.resolve("tuf", in: [])
            Issue.record("resolution should have failed")
        } catch let failure as CLIFailure {
            #expect(failure.kind == .notFound)
            #expect(failure.hint?.contains("Machines") == true)
        } catch {
            Issue.record("unexpected error \(error)")
        }
    }

    @Test func summaryCarriesTheFieldsAnAgentNeeds() {
        guard case let .object(fields) = MachineDirectory.summary(Self.alias) else {
            Issue.record("summary should be an object")
            return
        }
        #expect(fields["name"] == .string("Asus TUF 7"))
        #expect(fields["sshAlias"] == .string("tuf"))
        #expect(fields["sshTarget"] == .string("tuf"))
        #expect(fields["source"] == .string("sshConfigAlias"))
        #expect(fields["port"] == .int(22))
    }

    @Test func manualMachinesReportNoAlias() {
        guard case let .object(fields) = MachineDirectory.summary(Self.manual) else {
            Issue.record("summary should be an object")
            return
        }
        #expect(fields["sshAlias"] == .null)
        #expect(fields["sshTarget"] == .string("root@10.0.0.9"))
        #expect(fields["port"] == .int(2222))
    }

    @Test func loadingAMissingFileYieldsNoMachinesRatherThanCrashing() {
        let missing = URL(fileURLWithPath: "/nonexistent/machines.json")
        #expect(MachineDirectory.load(from: missing).isEmpty)
    }

    @Test func samplesEncodeIntoStableFieldNames() {
        let sample = MachineSample(
            ts: 1_700_000_000, dt: 2, cpu: MachineCPU(total: 12.5, steal: 0, cores: [10, 15]),
            mem: MachineMemory(totalKB: 1000, availKB: 400, usedKB: 600),
            load: [1, 2, 3], tasks: MachineTasks(runnable: 1, total: 200), uptime: 60,
            net: MachineNetwork(rxBps: 100, txBps: 50))
        guard case let .object(fields) = MachineReports.sample(sample),
            case let .object(cpu)? = fields["cpu"],
            case let .object(memory)? = fields["memory"]
        else {
            Issue.record("sample should be a nested object")
            return
        }
        #expect(cpu["totalPercent"] == .double(12.5))
        #expect(memory["usedPercent"] == .double(60))
        #expect(fields["load"] == .doubles([1, 2, 3]))
    }

    @Test func dockerAvailabilityIsReportedAsAState() {
        #expect(
            MachineReports.availability(DockerAvailability(status: .missing))
                == .object(["state": .string("missing")]))
        guard
            case let .object(fields) = MachineReports.availability(
                DockerAvailability(status: .available(serverVersion: "27.0", hasCompose: true)))
        else {
            Issue.record("availability should be an object")
            return
        }
        #expect(fields["serverVersion"] == .string("27.0"))
        #expect(fields["compose"] == .bool(true))
    }
}
