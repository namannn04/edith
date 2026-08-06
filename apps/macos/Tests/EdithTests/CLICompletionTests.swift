import ArgumentParser
import Foundation
import Testing

@testable import EdithCLI
@testable import EdithKit

@Suite struct CLICompletionTests {
    static let machines = ["Asus TUF 7", "tuf"]
    static let extensionIDs = ExtensionRegistry.entries.map(\.id)

    static func plan(_ words: [String], _ index: Int) -> CompletionResult {
        CompletionEngine.plan(
            CompletionRequest(words: words, index: index), machines: machines,
            configKeys: ConfigCatalog.keys, extensionIDs: extensionIDs)
    }

    @Test func theTopLevelOffersCommandsAndMachines() {
        let result = Self.plan(["ed", ""], 1)
        #expect(result.candidates.contains("config"))
        #expect(result.candidates.contains("machines"))
        #expect(result.candidates.contains("tuf"))
        #expect(result.remoteMachine == nil)
    }

    @Test func candidatesAreFilteredByThePrefix() {
        let result = Self.plan(["ed", "mac"], 1)
        #expect(result.candidates == ["machines"])
    }

    @Test func namingAMachineFirstHandsOverToRemoteCompletion() {
        let result = Self.plan(["ed", "tuf", "doc"], 2)
        #expect(result.remoteMachine == "tuf")
        #expect(result.candidates.isEmpty)
    }

    @Test func aReservedWordIsNeverTreatedAsAMachine() {
        let result = Self.plan(["ed", "config", ""], 2)
        #expect(result.remoteMachine == nil)
        #expect(result.candidates.contains("set"))
    }

    @Test func settingKeysCompleteWhereAKeyGoes() {
        let result = Self.plan(["ed", "config", "set", "presenterB"], 3)
        #expect(result.candidates.contains("presenterBlurMoney"))
        #expect(!result.candidates.contains("warnPercent"))
    }

    @Test func allowedValuesCompleteAfterTheirKey() {
        let result = Self.plan(["ed", "config", "set", "limitsProvider", ""], 4)
        #expect(result.candidates == ["claude", "codex"])
    }

    @Test func booleanSettingsOfferTrueAndFalse() {
        let result = Self.plan(["ed", "config", "set", "preventSleep", ""], 4)
        #expect(result.candidates == ["true", "false"])
    }

    @Test func extensionIDsCompleteForEnable() {
        let result = Self.plan(["ed", "extensions", "enable", "cli"], 3)
        #expect(result.candidates == ["clipboard"])
    }

    @Test func machineNamesCompleteInsideTheMachinesTree() {
        let result = Self.plan(["ed", "machines", "docker", "ps", ""], 4)
        #expect(result.candidates.contains("tuf"))
    }

    @Test func flagsCompleteWhenTheWordStartsWithADash() {
        let result = Self.plan(["ed", "machines", "ls", "--j"], 3)
        #expect(result.candidates == ["--json"])
    }

    @Test func localPathsAskTheShellForFiles() {
        let result = Self.plan(["ed", "config", "import", ""], 3)
        #expect(result.wantsFiles)
        #expect(result.lines.first == "#files")
    }

    @Test func theTerminatorIsNotMistakenForTheProgramName() {
        let stripped = CompletionRequest.stripSeparator(["--", "ed", "config"])
        #expect(stripped == ["ed", "config"])
    }

    @Test func remoteCompletionAsksForCommandNamesAtTheFirstWord() {
        let command = RemoteCompletion.commandNamesCommand(prefix: "doc")
        #expect(command.hasPrefix("compgen -c -- doc"))
    }

    @Test func remoteCompletionForwardsTheWholeWordListToBash() {
        let command = RemoteCompletion.harnessCommand(
            words: ["docker", "compose", ""], cursor: 2)
        #expect(command.hasPrefix("bash -c "))
        #expect(command.contains("ed-complete 2 docker compose"))
        #expect(command.contains("_completion_loader"))
    }

    @Test func everyCompletionTreeNodeExistsInTheParser() throws {
        var missing: [String] = []
        check(node: CommandTree.root, command: EdRoot.self, path: [], missing: &missing)
        #expect(
            missing.isEmpty, "completion tree names commands the parser does not have: \(missing)")
    }

    private func check(
        node: CommandNode, command: ParsableCommand.Type, path: [String], missing: inout [String]
    ) {
        let declared = command.configuration.subcommands
        for child in node.children {
            guard
                let match = declared.first(where: {
                    $0.configuration.commandName == child.name
                        || $0.configuration.aliases.contains(child.name)
                })
            else {
                missing.append((path + [child.name]).joined(separator: " "))
                continue
            }
            check(node: child, command: match, path: path + [child.name], missing: &missing)
        }
    }
}

@Suite struct CLIArgumentRewritingTests {
    static let machines = ["Asus TUF 7", "tuf"]

    @Test func aMachineNameTurnsIntoARemoteExec() {
        #expect(
            ArgumentRewriting.rewrite(["tuf", "docker", "ps"], machines: Self.machines)
                == ["machines", "exec", "tuf", "--", "docker", "ps"])
    }

    @Test func machineNamesAreMatchedCaseInsensitively() {
        #expect(
            ArgumentRewriting.rewrite(["TUF", "uptime"], machines: Self.machines)
                == ["machines", "exec", "TUF", "--", "uptime"])
    }

    @Test func aBareMachineNameShowsTheMachine() {
        #expect(
            ArgumentRewriting.rewrite(["tuf"], machines: Self.machines)
                == ["machines", "show", "tuf"])
    }

    @Test func reservedCommandsWinOverMachineNames() {
        #expect(
            ArgumentRewriting.rewrite(["config", "ls"], machines: ["config"])
                == ["config", "ls"])
        #expect(
            ArgumentRewriting.rewrite(["__complete", "--index", "1"], machines: ["__complete"])
                == ["__complete", "--index", "1"])
    }

    @Test func flagsAndUnknownWordsAreLeftAlone() {
        #expect(ArgumentRewriting.rewrite(["--help"], machines: Self.machines) == ["--help"])
        #expect(
            ArgumentRewriting.rewrite(["nope", "ls"], machines: Self.machines) == ["nope", "ls"])
        #expect(ArgumentRewriting.rewrite([], machines: Self.machines) == [])
    }

    @Test func theSeparatorIsStrippedBeforeTheCommandReachesSSH() {
        #expect(MachinesExecCommand.strippingSeparator(["--", "ls", "-la"]) == ["ls", "-la"])
        #expect(MachinesExecCommand.strippingSeparator(["ls", "-la"]) == ["ls", "-la"])
    }
}
