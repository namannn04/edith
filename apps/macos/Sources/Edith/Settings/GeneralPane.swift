import AppKit
import Carbon.HIToolbox
import EdithKit
import SwiftUI

struct GeneralPane: View {
    @AppStorage("appearance", store: SharedDefaults.store) private var appearance = "system"
    @AppStorage("theme", store: SharedDefaults.store) private var themeName = "accent"
    @AppStorage("lastPaletteTheme", store: SharedDefaults.store) private var lastPaletteTheme =
        "blue"
    @AppStorage("showDockIcon", store: SharedDefaults.store) private var showDockIcon = true

    var body: some View {
        Form {
            Section {
                Picker("Appearance", selection: $appearance) {
                    Text("System").tag("system")
                    Text("Light").tag("light")
                    Text("Dark").tag("dark")
                }
                .pointerCursor()
                .onChange(of: appearance) { _, value in applyAppearance(value) }

                LabeledContent("Theme") {
                    HStack(spacing: 10) {
                        Toggle(
                            "Use accent",
                            isOn: Binding(
                                get: { themeName == "accent" },
                                set: { themeName = $0 ? "accent" : lastPaletteTheme })
                        )
                        .toggleStyle(.switch)
                        .pointerCursor()
                        ForEach(themePalette, id: \.name) { entry in
                            swatch(entry.name, color: entry.color)
                        }
                    }
                    .opacity(themeName == "accent" ? 0.5 : 1)
                }
            } header: {
                Text("Appearance")
            }

            Section {
                Toggle("Show Dock icon", isOn: $showDockIcon)
                    .pointerCursor()
                    .onChange(of: showDockIcon) { _, on in
                        NSApp.setActivationPolicy(on ? .regular : .accessory)
                    }
                HStack {
                    LabeledContent("Panel shortcut") {
                        HotKeyRecorderControl(keyPrefix: "hotKey", defaultLabel: "⌥⌘E")
                    }
                    InfoDot(
                        "The keyboard shortcut that opens Edith's menu bar panel, from anywhere."
                    )
                }
            } header: {
                Text("Window")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("General")
    }

    private func swatch(_ name: String, color: Color) -> some View {
        Button {
            themeName = name
            lastPaletteTheme = name
        } label: {
            ZStack {
                Circle().fill(color).frame(width: 20, height: 20)
                if themeName == name {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
        }
        .buttonStyle(.plain)
        .pointerCursor()
    }
}
