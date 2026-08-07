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
                == "cd /home/pulkit 2>/dev/null; cd -- Desktop && pwd")
    }

    @Test func sendsABareChangeDirectoryHome() {
        #expect(MachineWorkingDirectory.resolveCommand(target: nil, from: nil) == "cd && pwd")
    }

    @Test func spotsAChangeDirectoryCommand() {
        #expect(MachineWorkingDirectory.isChangeDirectory(["cd"]))
        #expect(MachineWorkingDirectory.isChangeDirectory(["cd", "Desktop"]))
        #expect(!MachineWorkingDirectory.isChangeDirectory(["cd", "a", "b"]))
        #expect(!MachineWorkingDirectory.isChangeDirectory(["ls"]))
        #expect(!MachineWorkingDirectory.isChangeDirectory(["cd Desktop && pwd"]))
    }
}
