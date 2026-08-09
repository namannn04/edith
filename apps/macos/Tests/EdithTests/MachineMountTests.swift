import Foundation
import Testing

@testable import EdithKit

@Suite struct MachineMountTests {
    private let machine = Machine(
        id: UUID(uuidString: "11111111-2222-3333-4444-555555555555")!, name: "tuf",
        host: "10.0.0.4", port: 2222, username: "pulkit")

    @Test func onlyFuseLinesCountAsMachineMounts() {
        let output = """
            /dev/disk3s1s1 on / (apfs, sealed, local, read-only, journaled)
            pulkit@10.0.0.4:/home/pulkit on /Users/pulkit/Edith/tuf (macfuse, nodev, nosuid)
            map auto_home on /System/Volumes/Data/home (autofs, automounted)
            """
        let mounts = MachineMounts.parse(output)
        #expect(mounts.count == 1)
        #expect(mounts.first?.target == "pulkit@10.0.0.4")
        #expect(mounts.first?.remotePath == "/home/pulkit")
        #expect(mounts.first?.mountPoint == "/Users/pulkit/Edith/tuf")
        #expect(mounts.first?.isReadOnly == false)
    }

    @Test func aReadOnlyMountIsReportedAsOne() {
        let mounts = MachineMounts.parse(
            "pi@box:/srv on /Users/pulkit/Edith/pi (macfuse, read-only, nodev)")
        #expect(mounts.first?.isReadOnly == true)
    }

    @Test func aMachineIsMatchedByItsSSHTarget() {
        let mounts = MachineMounts.parse(
            "pulkit@10.0.0.4:/home/pulkit on /Users/pulkit/Edith/tuf (macfuse, nodev)")
        #expect(MachineMounts.mount(for: machine, in: mounts)?.remotePath == "/home/pulkit")
        let other = Machine(name: "pi", host: "box", username: "pi")
        #expect(MachineMounts.mount(for: other, in: mounts) == nil)
    }

    @Test func theMountPointIsNamedAfterTheMachine() {
        #expect(MachineMounts.mountPoint(for: machine).lastPathComponent == "tuf")
        let awkward = Machine(name: "web/prod", host: "h")
        #expect(MachineMounts.folderName(for: awkward) == "web-prod")
    }

    @Test func theMountRidesTheSharedControlSocket() {
        let arguments = MachineMounts.mountArguments(
            machine: machine, remotePath: "/srv", mountPoint: "/Users/pulkit/Edith/tuf",
            readOnly: false)
        #expect(arguments.first == "pulkit@10.0.0.4:/srv")
        #expect(arguments[1] == "/Users/pulkit/Edith/tuf")
        #expect(
            arguments.contains("ControlPath=\(MachinePaths.socketFile(for: machine.id).path)"))
        #expect(arguments.contains("ControlMaster=no"))
        #expect(arguments.contains("BatchMode=yes"))
        #expect(arguments.contains("volname=tuf"))
        #expect(!arguments.contains("ro"))
    }

    @Test func aManualMachineCarriesItsPortAndKey() {
        var keyed = machine
        keyed.auth = .keyFile(path: "/tmp/id_ed25519", hasPassphrase: false)
        let arguments = MachineMounts.mountArguments(
            machine: keyed, remotePath: "/srv", mountPoint: "/mnt/tuf", readOnly: true)
        #expect(arguments.contains("-p"))
        #expect(arguments.contains("2222"))
        #expect(arguments.contains("IdentityFile=/tmp/id_ed25519"))
        #expect(arguments.contains("ro"))
    }

    @Test func anAliasMachineIsLeftToTheSSHConfig() {
        var alias = machine
        alias.source = .sshConfigAlias("tuf-alias")
        let arguments = MachineMounts.mountArguments(
            machine: alias, remotePath: "/srv", mountPoint: "/mnt/tuf", readOnly: false)
        #expect(arguments.first == "tuf-alias:/srv")
        #expect(!arguments.contains("-p"))
    }

    @Test func aMountPointWithSomethingInItIsRefused() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        #expect(throws: Never.self) { try MachineMounts.prepare(directory) }
        FileManager.default.createFile(
            atPath: directory.appendingPathComponent("busy").path, contents: Data())
        #expect(throws: MachineMountError.mountPointBusy(directory.path)) {
            try MachineMounts.prepare(directory)
        }
    }
}
