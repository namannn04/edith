import Foundation
import Testing

@testable import EdithKit

@Suite struct MachineWorkingDirectoryTests {
    private let machine = UUID(uuidString: "4303DCF1-52AA-4BBB-8CCC-9DDDEEEFFF00")!

    @Test func namesASessionAfterItsTerminal() {
        #expect(MachineWorkingDirectory.sanitize("/dev/ttys004") == "ttys004")
        #expect(MachineWorkingDirectory.sanitize("/dev/pts/3") == "pts-3")
        #expect(MachineWorkingDirectory.sanitize("/dev/") == "shared")
    }

    @Test func fallsBackToASharedSessionWithoutATerminal() {
        #expect(MachineWorkingDirectory.sessionKey(descriptor: -1) == "shared")
    }

    @Test func keepsEachTerminalSeparate() {
        MachineWorkingDirectory.save("/etc", machineID: machine, session: "ttys009")
        MachineWorkingDirectory.save("/var", machineID: machine, session: "ttys023")
        defer {
            MachineWorkingDirectory.clear(machineID: machine, session: "ttys009")
            MachineWorkingDirectory.clear(machineID: machine, session: "ttys023")
        }
        #expect(MachineWorkingDirectory.load(machineID: machine, session: "ttys009") == "/etc")
        #expect(MachineWorkingDirectory.load(machineID: machine, session: "ttys023") == "/var")
    }

    @Test func forgetsADirectoryOnceCleared() {
        MachineWorkingDirectory.save("/etc", machineID: machine, session: "ttys001")
        MachineWorkingDirectory.clear(machineID: machine, session: "ttys001")
        #expect(MachineWorkingDirectory.load(machineID: machine, session: "ttys001") == nil)
    }

    @Test func treatsAnEmptyDirectoryAsNoDirectory() {
        MachineWorkingDirectory.save("/etc", machineID: machine, session: "ttys002")
        MachineWorkingDirectory.save("   ", machineID: machine, session: "ttys002")
        #expect(MachineWorkingDirectory.load(machineID: machine, session: "ttys002") == nil)
    }

    @Test func runsCommandsWhereTheSessionLeftOff() {
        #expect(
            MachineWorkingDirectory.prefixed("pwd", directory: "/home/pulkit/Desktop")
                == "cd /home/pulkit/Desktop 2>/dev/null || cd; pwd")
    }

    @Test func leavesCommandsAloneWithoutARememberedDirectory() {
        #expect(MachineWorkingDirectory.prefixed("pwd", directory: nil) == "pwd")
        #expect(MachineWorkingDirectory.prefixed("pwd", directory: "") == "pwd")
    }

    @Test func quotesADirectoryThatNeedsIt() {
        let command = MachineWorkingDirectory.prefixed("ls", directory: "/tmp/a b'c")
        #expect(command == "cd '/tmp/a b'\\''c' 2>/dev/null || cd; ls")
    }

    @Test func resolvesARelativeTargetAgainstTheCurrentDirectory() {
        #expect(
            MachineWorkingDirectory.resolveCommand(target: "Desktop", from: "/home/pulkit")
                == "cd /home/pulkit 2>/dev/null; pwd; cd -- Desktop && pwd")
    }

    @Test func sendsABareChangeDirectoryHome() {
        #expect(
            MachineWorkingDirectory.resolveCommand(target: nil, from: nil)
                == "pwd; cd && pwd")
    }

    @Test func spotsAChangeDirectoryCommand() {
        #expect(MachineWorkingDirectory.isChangeDirectory(["cd"]))
        #expect(MachineWorkingDirectory.isChangeDirectory(["cd", "Desktop"]))
        #expect(!MachineWorkingDirectory.isChangeDirectory(["cd", "a", "b"]))
        #expect(!MachineWorkingDirectory.isChangeDirectory(["ls"]))
        #expect(!MachineWorkingDirectory.isChangeDirectory(["cd Desktop && pwd"]))
    }

    @Test func keepsOnlyTheLastLineOfTheRemoteReply() {
        #expect(
            MachineWorkingDirectory.resolvedDirectory(fromOutput: "/home/pulkit\n/home/pulkit\n")
                == "/home/pulkit")
        #expect(MachineWorkingDirectory.resolvedDirectory(fromOutput: "  \n \n") == nil)
        #expect(MachineWorkingDirectory.resolvedDirectory(fromOutput: "") == nil)
    }

    @Test func remembersTheDirectoryItCameFrom() {
        MachineWorkingDirectory.save(
            "/home/pulkit/Desktop", previous: "/home/pulkit", machineID: machine,
            session: "ttys003")
        defer { MachineWorkingDirectory.clear(machineID: machine, session: "ttys003") }
        #expect(
            MachineWorkingDirectory.load(machineID: machine, session: "ttys003")
                == "/home/pulkit/Desktop")
        #expect(
            MachineWorkingDirectory.loadPrevious(machineID: machine, session: "ttys003")
                == "/home/pulkit")
    }

    @Test func hasNoPreviousDirectoryUntilItMovesTwice() {
        MachineWorkingDirectory.save("/etc", machineID: machine, session: "ttys004")
        defer { MachineWorkingDirectory.clear(machineID: machine, session: "ttys004") }
        #expect(MachineWorkingDirectory.loadPrevious(machineID: machine, session: "ttys004") == nil)
    }

    @Test func readsWhereTheMoveStartedFromTheFirstLine() {
        let reply = "/home/pulkit\n/home/pulkit/Desktop\n"
        #expect(MachineWorkingDirectory.originDirectory(fromOutput: reply) == "/home/pulkit")
        #expect(
            MachineWorkingDirectory.resolvedDirectory(fromOutput: reply)
                == "/home/pulkit/Desktop")
    }
}
