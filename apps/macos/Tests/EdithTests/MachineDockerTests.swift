import Foundation
import Testing

@testable import EdithKit

@Suite struct DockerParsingTests {
    private let psOutput = """
        {"Command":"\\"docker-entrypoint.s…\\"","CreatedAt":"2026-08-01 10:23:45 +0000 UTC",\
        "ID":"a1b2c3d4e5f60000000000000000000000000000000000000000000000000000",\
        "Image":"postgres:16","Labels":"com.docker.compose.project=api,\
        com.docker.compose.service=db","Names":"api-db-1",\
        "Ports":"0.0.0.0:5432->5432/tcp, :::5432->5432/tcp","State":"running",\
        "Status":"Up 2 hours (healthy)"}
        {"Command":"\\"nginx\\"","CreatedAt":"2026-07-30 08:00:00 +0000 UTC",\
        "ID":"ffffeeee111122223333444455556666777788889999aaaabbbbccccddddeeee",\
        "Image":"nginx:alpine","Labels":"","Names":"web","Ports":"","State":"exited",\
        "Status":"Exited (0) 3 days ago"}
        """

    @Test func parsesContainers() {
        let containers = DockerParsing.containers(psOutput: psOutput)
        #expect(containers.count == 2)
        let db = containers[0]
        #expect(db.displayName == "api-db-1")
        #expect(db.image == "postgres:16")
        #expect(db.state == .running)
        #expect(db.health == .healthy)
        #expect(db.composeProject == "api")
        #expect(db.composeService == "db")
        #expect(db.shortID == "a1b2c3d4e5f6")
        let web = containers[1]
        #expect(web.state == .exited)
        #expect(web.health == .none)
        #expect(web.ports.isEmpty)
        #expect(web.composeProject == nil)
    }

    @Test func deduplicatesIPv4AndIPv6PortEntries() {
        let ports = DockerParsing.parsePorts("0.0.0.0:5432->5432/tcp, :::5432->5432/tcp")
        #expect(ports.count == 1)
        #expect(ports[0].hostPort == 5432)
        #expect(ports[0].containerPort == 5432)
        #expect(ports[0].proto == "tcp")
        #expect(ports[0].browserURL?.absoluteString == "http://localhost:5432")
    }

    @Test func parsesUnpublishedPorts() {
        let ports = DockerParsing.parsePorts("80/tcp, 443/tcp")
        #expect(ports.map(\.containerPort) == [80, 443])
        #expect(ports.allSatisfy { $0.hostPort == nil })
        #expect(ports[0].browserURL == nil)
        #expect(ports[0].displayName == "80/tcp")
    }

    @Test func parsesBinaryAndDecimalSizes() {
        #expect(DockerParsing.parseSize("7.75MiB") == Int64(7.75 * 1_048_576))
        #expect(DockerParsing.parseSize("15.61GiB") == Int64(15.61 * 1_073_741_824))
        #expect(DockerParsing.parseSize("125MB") == 125_000_000)
        #expect(DockerParsing.parseSize("658kB") == 658_000)
        #expect(DockerParsing.parseSize("0B") == 0)
        #expect(DockerParsing.parseSize("N/A") == nil)
        #expect(DockerParsing.parseSize("--") == nil)
    }

    @Test func parsesPercentagesIncludingMulticoreAndSentinels() {
        #expect(DockerParsing.parsePercent("1.53%") == 1.53)
        #expect(DockerParsing.parsePercent("235.00%") == 235.0)
        #expect(DockerParsing.parsePercent("--") == nil)
    }

    @Test func mergesStatsIntoContainers() {
        let stats = """
            {"ID":"a1b2c3d4e5f6","Name":"api-db-1","CPUPerc":"1.53%","MemPerc":"0.05%",\
            "MemUsage":"7.75MiB / 15.61GiB","NetIO":"658kB / 45.2MB","BlockIO":"12.3MB / 0B",\
            "PIDs":"4"}
            """
        let merged = DockerParsing.applyStats(
            stats, to: DockerParsing.containers(psOutput: psOutput))
        #expect(merged[0].cpuPercent == 1.53)
        #expect(merged[0].memUsedBytes == Int64(7.75 * 1_048_576))
        #expect(merged[0].memLimitBytes == Int64(15.61 * 1_073_741_824))
        #expect(merged[0].netRxBytes == 658_000)
        #expect(merged[1].cpuPercent == nil)
    }

    @Test func parsesImagesAndFlagsDangling() {
        let output = """
            {"ID":"sha256:aaaa1111bbbb2222","Repository":"nginx","Tag":"alpine",\
            "CreatedSince":"5 days ago","Size":"48.2MB"}
            {"ID":"sha256:cccc3333","Repository":"<none>","Tag":"<none>",\
            "CreatedSince":"2 weeks ago","Size":"1.1GB"}
            """
        let images = DockerParsing.images(output)
        #expect(images.count == 2)
        #expect(images[0].displayName == "nginx:alpine")
        #expect(images[0].sizeBytes == 48_200_000)
        #expect(images[0].shortID == "aaaa1111bbbb")
        #expect(!images[0].dangling)
        #expect(images[1].dangling)
        #expect(images[1].displayName == "<none>:<none>")
    }

    @Test func parsesVolumesAndMergesSystemDFDetails() {
        let volumes = DockerParsing.volumes(
            """
            {"Name":"api_pgdata","Driver":"local","Mountpoint":"/var/lib/docker/volumes/api_pgdata"}
            """)
        #expect(volumes.count == 1)
        #expect(!volumes[0].inUse)
        let details = DockerParsing.volumeDetails(
            systemDFOutput: """
                {"Volumes":[{"Name":"api_pgdata","Links":2,"Size":"312MB"}]}
                """)
        #expect(details["api_pgdata"]?.0 == 312_000_000)
        #expect(details["api_pgdata"]?.1 == 2)
    }

    @Test func parsesDiskUsageReclaimable() {
        let usage = DockerParsing.diskUsage(
            """
            {"Type":"Images","TotalCount":"12","Active":"5","Size":"2.631GB",\
            "Reclaimable":"2.498GB (94%)"}
            """)
        #expect(usage.count == 1)
        #expect(usage[0].sizeBytes == 2_631_000_000)
        #expect(usage[0].reclaimableBytes == 2_498_000_000)
        #expect(usage[0].totalCount == 12)
    }

    @Test func ignoresNonJSONNoise() {
        let output = """
            Welcome to Ubuntu 24.04 LTS
            {"ID":"abc","Repository":"nginx","Tag":"latest","Size":"1MB","CreatedSince":"now"}
            """
        #expect(DockerParsing.images(output).count == 1)
    }

    @Test func splitsTimestampedLogLines() {
        let line = DockerParsing.splitLogLine(
            "2026-08-06T12:34:56.789012345Z starting server on :3000", index: 0, isStderr: false)
        #expect(line.timestamp == "2026-08-06T12:34:56.789012345Z")
        #expect(line.text == "starting server on :3000")

        let plain = DockerParsing.splitLogLine("no timestamp here", index: 1, isStderr: true)
        #expect(plain.timestamp == nil)
        #expect(plain.text == "no timestamp here")
        #expect(plain.isStderr)
    }

    @Test func detectsAvailabilityStates() {
        let ok = DockerParsing.availability(
            versionOutput: "{\"Client\":{\"Version\":\"27.0\"},\"Server\":{\"Version\":\"27.0\"}}",
            versionStderr: "", status: 0)
        #expect(ok.isAvailable)

        let denied = DockerParsing.availability(
            versionOutput: "",
            versionStderr: "permission denied while trying to connect to the Docker daemon socket",
            status: 1)
        #expect(denied.status == .permissionDenied)

        let missing = DockerParsing.availability(
            versionOutput: "", versionStderr: "bash: docker: command not found", status: 127)
        #expect(missing.status == .missing)

        let down = DockerParsing.availability(
            versionOutput: "",
            versionStderr: "Cannot connect to the Docker daemon at unix:///var/run/docker.sock.",
            status: 1)
        #expect(down.status == .daemonDown(message: "The Docker daemon is not running."))
    }
}

@Suite struct DockerCommandsTests {
    @Test func usesGoTemplateJSONFormatEverywhere() {
        #expect(DockerCommands.images().contains("'{{json .}}'"))
        #expect(DockerCommands.volumes().contains("'{{json .}}'"))
        #expect(!DockerCommands.images().contains("--format json"))
    }

    @Test func batchesContainersAndStatsWithSeparator() {
        let command = DockerCommands.containersWithStats()
        #expect(command.contains("docker ps -a --no-trunc"))
        #expect(command.contains(DockerCommands.listSeparator))
        #expect(command.contains("docker stats --no-stream"))
    }

    @Test func quotesIdentifiersInLifecycleCommands() {
        #expect(DockerCommands.lifecycle("stop", id: "web") == "docker stop -t 10 web")
        #expect(DockerCommands.lifecycle("rm", id: "a b") == "docker rm -f 'a b'")
        #expect(DockerCommands.lifecycle("start", id: "$(evil)") == "docker start '$(evil)'")
    }

    @Test func execShellFallsBackFromBashToSh() {
        let command = DockerCommands.execShell(containerID: "web")
        #expect(command.hasPrefix("docker exec -it web sh -c "))
        #expect(command.contains("command -v bash"))
        #expect(command.contains("exec sh"))
    }

    @Test func logsCommandCarriesTimestampsAndTail() {
        let command = DockerCommands.logs("web", tail: 200, follow: true)
        #expect(command == "docker logs --timestamps --tail 200 --follow web")
    }
}

@Suite struct FileListingTests {
    @Test func parsesFindOutput() {
        let sep = FileListing.separator
        let output = [
            "d\(sep)4096\(sep)1754000000.0\(sep)755\(sep)projects\(sep)",
            "f\(sep)2048\(sep)1754000100.5\(sep)644\(sep)notes.md\(sep)",
            "l\(sep)12\(sep)1754000200.0\(sep)777\(sep)link\(sep)/etc/hosts",
        ].joined(separator: "\n")
        let entries = FileListing.parse(output: output, parent: "/home/pulkit")
        #expect(entries.map(\.name) == ["projects", "link", "notes.md"])
        #expect(entries[0].kind == .directory)
        #expect(entries[0].path == "/home/pulkit/projects")
        #expect(entries[1].kind == .symlink)
        #expect(entries[1].linkTarget == "/etc/hosts")
        #expect(entries[2].sizeBytes == 2048)
        #expect(entries[2].modified == Date(timeIntervalSince1970: 1_754_000_100.5))
    }

    @Test func sortsDirectoriesFirstThenCaseInsensitively() {
        let sep = FileListing.separator
        let output = [
            "f\(sep)1\(sep)1\(sep)644\(sep)zeta.txt\(sep)",
            "f\(sep)1\(sep)1\(sep)644\(sep)Alpha.txt\(sep)",
            "d\(sep)1\(sep)1\(sep)755\(sep)src\(sep)",
        ].joined(separator: "\n")
        let entries = FileListing.parse(output: output, parent: "/x")
        #expect(entries.map(\.name) == ["src", "Alpha.txt", "zeta.txt"])
    }

    @Test func fallsBackToLSParsing() {
        let output = """
            total 12
            drwxr-xr-x 3 1000 1000 4096 1754000000 projects
            -rw-r--r-- 1 1000 1000 2048 1754000100 notes.md
            lrwxrwxrwx 1 1000 1000 12 1754000200 link -> /etc/hosts
            """
        let entries = FileListing.parse(output: output, parent: "/home/pulkit")
        #expect(entries.map(\.name) == ["projects", "link", "notes.md"])
        #expect(entries[0].kind == .directory)
        #expect(entries[1].linkTarget == "/etc/hosts")
        #expect(entries[2].sizeBytes == 2048)
    }

    @Test func joinsAndWalksPaths() {
        #expect(FileListing.join(parent: "/", name: "etc") == "/etc")
        #expect(FileListing.join(parent: "/home", name: "pulkit") == "/home/pulkit")
        #expect(FileListing.join(parent: "/home/", name: "pulkit") == "/home/pulkit")
        #expect(FileListing.parentPath(of: "/home/pulkit") == "/home")
        #expect(FileListing.parentPath(of: "/home") == "/")
        #expect(FileListing.parentPath(of: "/") == nil)
    }

    @Test func buildsBreadcrumbs() {
        let crumbs = FileListing.breadcrumbs(for: "/home/pulkit/code")
        #expect(crumbs.map(\.name) == ["/", "home", "pulkit", "code"])
        #expect(crumbs.map(\.path) == ["/", "/home", "/home/pulkit", "/home/pulkit/code"])
    }

    @Test func quotesPathsWithSpaces() {
        let command = FileListing.command(path: "/mnt/My Files", showHidden: true)
        #expect(command.contains("'/mnt/My Files'"))
    }

    @Test func detectsHiddenEntries() {
        let entry = RemoteFileEntry(
            name: ".bashrc", path: "/home/p/.bashrc", kind: .file, sizeBytes: 10)
        #expect(entry.isHidden)
        #expect(entry.fileExtension == "bashrc")
    }
}

@Suite struct FilePreviewKindTests {
    @Test func routesByExtension() {
        #expect(FilePreviewKind.kind(forExtension: "swift") == .text)
        #expect(FilePreviewKind.kind(forExtension: "JSON") == .text)
        #expect(FilePreviewKind.kind(forExtension: "png") == .image)
        #expect(FilePreviewKind.kind(forExtension: "pdf") == .pdf)
        #expect(FilePreviewKind.kind(forExtension: "mp4") == .media)
        #expect(FilePreviewKind.kind(forExtension: "mkv") == .unsupported)
        #expect(FilePreviewKind.kind(forExtension: "webm") == .unsupported)
        #expect(FilePreviewKind.kind(forExtension: "docx") == .quickLook)
        #expect(FilePreviewKind.kind(forExtension: "") == .quickLook)
    }

    @Test func recognizesExtensionlessTextFiles() {
        #expect(FilePreviewKind.isPlainTextName("Dockerfile"))
        #expect(FilePreviewKind.isPlainTextName("/etc/Makefile"))
        #expect(!FilePreviewKind.isPlainTextName("binary"))
    }
}

@Suite struct ByteFormatterTests {
    @Test func formatsBytes() {
        #expect(ByteFormatter.string(0) == "0 B")
        #expect(ByteFormatter.string(512) == "512 B")
        #expect(ByteFormatter.string(2048) == "2.0 KB")
        #expect(ByteFormatter.string(1_500_000) == "1.5 MB")
        #expect(ByteFormatter.string(250_000_000) == "250 MB")
    }

    @Test func formatsRatesAndDurations() {
        #expect(ByteFormatter.rate(1_500_000) == "1.5 MB/s")
        #expect(ByteFormatter.rate(-5) == "0 B/s")
        #expect(ByteFormatter.duration(90) == "1m")
        #expect(ByteFormatter.duration(3700) == "1h 1m")
        #expect(ByteFormatter.duration(200_000) == "2d 7h")
    }
}

@Suite struct MachineFactsTests {
    @Test func parsesWhoOutput() {
        let who = MachineFacts.parseWho(
            "pulkit   pts/0        2026-08-06 10:11 (192.168.1.9)\nroot     tty1  2026-08-05 09:00")
        #expect(who.count == 2)
        #expect(who[0].hasPrefix("pulkit on pts/0 since 2026-08-06 10:11"))
    }

    @Test func parsesUpdateCountsAndSentinel() {
        #expect(MachineFacts.parseUpdates("12\n") == 12)
        #expect(MachineFacts.parseUpdates("0") == 0)
        #expect(MachineFacts.parseUpdates("-1") == nil)
        #expect(MachineFacts.parseUpdates("garbage") == nil)
    }

    @Test func validatesMACAddress() {
        #expect(MachineFacts.parseMACAddress("AA:BB:CC:DD:EE:FF\n") == "aa:bb:cc:dd:ee:ff")
        #expect(MachineFacts.parseMACAddress("not-a-mac") == nil)
    }

    @Test func buildsWakeOnLANMagicPacket() {
        let packet = WakeOnLAN.magicPacket(macAddress: "aa:bb:cc:dd:ee:ff")
        #expect(packet?.count == 102)
        #expect(packet?.prefix(6) == Data(repeating: 0xFF, count: 6))
        #expect(WakeOnLAN.magicPacket(macAddress: "bogus") == nil)
    }
}

@Suite struct ServiceCommandsTests {
    @Test func parsesSystemctlUnits() {
        let output = """
            docker.service loaded active running Docker Application Container Engine
            ssh.service    loaded active running OpenBSD Secure Shell server
            broken.service loaded failed failed  Some Broken Unit
            dev-sda.device loaded active plugged ignored
            """
        let services = ServiceCommands.parse(output)
        #expect(services.count == 3)
        #expect(services[0].displayName == "docker")
        #expect(services[0].isRunning)
        #expect(services[2].isFailed)
    }

    @Test func fallsBackToSudoForActions() {
        let command = ServiceCommands.action("restart", unit: "docker.service")
        #expect(command.contains("systemctl restart docker.service"))
        #expect(command.contains("sudo -n systemctl restart docker.service"))
    }

    @Test func journalCommandSupportsFollow() {
        #expect(
            ServiceCommands.journal(unit: "ssh.service", lines: 300, follow: true)
                == "journalctl -u ssh.service -n 300 --no-pager -f 2>&1")
    }
}

@Suite @MainActor struct MachineSessionHistoryTests {
    @Test func historyKeepsFixedWindow() {
        var history: [Double] = []
        for value in 0..<80 {
            history = MachineSession.appending(Double(value), to: history)
        }
        #expect(history.count == MachineSession.historyLength)
        #expect(history.first == 20)
        #expect(history.last == 79)
    }
}
