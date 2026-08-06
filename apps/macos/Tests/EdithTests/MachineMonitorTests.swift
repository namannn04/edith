import Foundation
import Testing

@testable import EdithHelper
@testable import EdithKit

@Suite struct MachineMonitorTests {
    private let disks = [
        MachineFilesystem(
            fs: "/dev/nvme0n1p2", mount: "/", totalKB: 100, usedKB: 95, availKB: 5),
        MachineFilesystem(
            fs: "/dev/nvme0n1p3", mount: "/home", totalKB: 100, usedKB: 40, availKB: 60),
    ]

    @Test func parsesDfOutput() {
        let parsed = MachineMonitor.parseDisks(
            "/dev/nvme0n1p2 500000000 250000000 225000000 /\n/dev/sda1 100 50 50 /mnt/My Disk")
        #expect(parsed.count == 2)
        #expect(parsed[0].mount == "/")
        #expect(parsed[0].usedPercent == 50.0)
        #expect(parsed[1].mount == "/mnt/My Disk")
    }

    @Test func flagsMountsOverThreshold() {
        #expect(MachineMonitorLogic.fullMounts(disks: disks, threshold: 90) == ["/"])
        #expect(MachineMonitorLogic.fullMounts(disks: disks, threshold: 99).isEmpty)
    }

    @Test func notifiesOnceWhenAMachineGoesOffline() {
        let previous = MachineHealth(reachable: true)
        let current = MachineHealth(reachable: false)
        let first = MachineMonitorLogic.alerts(
            machineName: "Tuf", previous: previous, current: current, disks: [], threshold: 90,
            notifyDown: true, notifyDisk: true)
        #expect(first == [.unreachable(machine: "Tuf")])

        let repeated = MachineMonitorLogic.alerts(
            machineName: "Tuf", previous: current, current: current, disks: [], threshold: 90,
            notifyDown: true, notifyDisk: true)
        #expect(repeated.isEmpty)
    }

    @Test func notifiesOnRecovery() {
        let alerts = MachineMonitorLogic.alerts(
            machineName: "Tuf", previous: MachineHealth(reachable: false),
            current: MachineHealth(reachable: true), disks: [], threshold: 90, notifyDown: true,
            notifyDisk: true)
        #expect(alerts == [.recovered(machine: "Tuf")])
    }

    @Test func notifiesOncePerNewlyFullDisk() {
        let previous = MachineHealth(reachable: true, fullMounts: [])
        let current = MachineHealth(reachable: true, fullMounts: ["/"])
        let alerts = MachineMonitorLogic.alerts(
            machineName: "Tuf", previous: previous, current: current, disks: disks, threshold: 90,
            notifyDown: true, notifyDisk: true)
        #expect(alerts == [.diskFull(machine: "Tuf", mount: "/", percent: 95)])

        let repeated = MachineMonitorLogic.alerts(
            machineName: "Tuf", previous: current, current: current, disks: disks, threshold: 90,
            notifyDown: true, notifyDisk: true)
        #expect(repeated.isEmpty)
    }

    @Test func respectsDisabledToggles() {
        let alerts = MachineMonitorLogic.alerts(
            machineName: "Tuf", previous: MachineHealth(reachable: true),
            current: MachineHealth(reachable: false), disks: disks, threshold: 90,
            notifyDown: false, notifyDisk: false)
        #expect(alerts.isEmpty)
    }

    @Test func skipsDiskAlertsWhileUnreachable() {
        let alerts = MachineMonitorLogic.alerts(
            machineName: "Tuf", previous: MachineHealth(reachable: true, fullMounts: []),
            current: MachineHealth(reachable: false, fullMounts: ["/"]), disks: disks,
            threshold: 90, notifyDown: false, notifyDisk: true)
        #expect(alerts.isEmpty)
    }

    @Test func alertIdentifiersAreStablePerConcern() {
        #expect(
            MachineAlert.unreachable(machine: "Tuf").identifier
                == MachineAlert.recovered(machine: "Tuf").identifier)
        #expect(
            MachineAlert.diskFull(machine: "Tuf", mount: "/", percent: 95).identifier
                != MachineAlert.diskFull(machine: "Tuf", mount: "/home", percent: 95).identifier)
    }

    @Test func alertCopyIsUserFacing() {
        let alert = MachineAlert.diskFull(machine: "Tuf", mount: "/", percent: 94.6)
        #expect(alert.title == "Tuf is running out of space")
        #expect(alert.body == "/ is 95% full.")
    }
}
