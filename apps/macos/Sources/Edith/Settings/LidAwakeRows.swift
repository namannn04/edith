import Combine
import EdithKit
import Foundation
import SwiftUI

struct LidAwakeRows: View {
    @AppStorage("lidAwakeEnabled", store: SharedDefaults.store) private var enabled = false
    @AppStorage("lidAwakeRestoreOnQuit", store: SharedDefaults.store) private var restoreOnQuit =
        true
    @State private var active = SharedDefaults.store.bool(forKey: LidAwakeState.activeKey)

    private var activeBinding: Binding<Bool> {
        Binding(get: { active }, set: { _ in IPC.post(IPC.Name.toggleLidAwake) })
    }

    var body: some View {
        Section {
            Toggle(isOn: activeBinding) {
                HStack(spacing: UIScale.pt(6)) {
                    Text("Lid awake")
                    InfoDot(
                        "Closing the lid normally sleeps the Mac even when Keep awake is on. This turns that pathway off, so the Mac keeps running with the lid shut - no external display or charger needed."
                    )
                }
            }
            .pointerCursor()
            Text(
                "macOS asks for an administrator password each time this changes, because the setting lives outside the app."
            )
            .font(.system(size: UIScale.pt(10))).foregroundStyle(.secondary)
            Toggle(isOn: $restoreOnQuit) {
                HStack(spacing: UIScale.pt(6)) {
                    Text("Restore normal sleep when Edith quits")
                    InfoDot(
                        "Leave this on so the Mac sleeps normally again once Edith is not running. Turning the extension off always restores it, whatever this is set to."
                    )
                }
            }
            .pointerCursor()
            Text(
                "While this is on the Mac stays awake with a closed lid, so it keeps drawing power and shedding heat. Do not put it in a bag like this."
            )
            .font(.system(size: UIScale.pt(10))).foregroundStyle(.secondary)
        }
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.5)
        .onAppear { active = SharedDefaults.store.bool(forKey: LidAwakeState.activeKey) }
        .onReceive(
            DistributedNotificationCenter.default().publisher(for: IPC.Name.lidAwakeChanged)
        ) { _ in
            active = SharedDefaults.store.bool(forKey: LidAwakeState.activeKey)
        }
    }
}
