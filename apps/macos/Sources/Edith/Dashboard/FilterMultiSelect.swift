import AppKit
import EdithKit
import SwiftUI

struct FilterSelectOption: Identifiable, Equatable {
    let id: String
    let label: String
}

struct FilterMultiSelect: View {
    let options: [FilterSelectOption]
    @Binding var selection: Set<String>
    let dark: Bool
    let dismiss: () -> Void

    @State private var anchor: String?

    private var order: [String] { options.map(\.id) }

    var body: some View {
        VStack(alignment: .leading, spacing: UIScale.pt(6)) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: UIScale.pt(1)) {
                    ForEach(options) { option in
                        FilterSelectRow(
                            label: option.label,
                            checked: selection.contains(option.id),
                            actionLabel: MultiSelectLogic.actionLabel(
                                option.id, selection: selection),
                            dark: dark,
                            onToggle: {
                                apply(MultiSelectLogic.toggle(option.id, selection: selection))
                            },
                            onRowClick: { toggleModifier, rangeModifier in
                                apply(
                                    MultiSelectLogic.rowClick(
                                        option.id, order: order, selection: selection,
                                        anchor: anchor, toggleModifier: toggleModifier,
                                        rangeModifier: rangeModifier))
                            },
                            onAction: {
                                apply(
                                    MultiSelectLogic.actionClick(
                                        option.id, order: order, selection: selection))
                            })
                    }
                }
            }
            .frame(maxHeight: UIScale.pt(320))
            Divider().opacity(0.4)
            HStack(spacing: UIScale.pt(8)) {
                Text(summary)
                    .font(DashSkin.mono(10))
                    .foregroundStyle(DashSkin.inkFaint(dark))
                Spacer(minLength: 0)
                if selection.count < options.count {
                    Button("Select all") { apply(MultiSelectLogic.selectAll(order: order)) }
                        .buttonStyle(.plain).pointerCursor()
                        .font(.system(size: UIScale.pt(10.5)))
                        .foregroundStyle(DashSkin.inkSoft(dark))
                }
                Button("Done") { dismiss() }
                    .buttonStyle(.plain).pointerCursor()
                    .font(.system(size: UIScale.pt(11), weight: .semibold))
                    .foregroundStyle(DashSkin.accent(dark))
            }
            .padding(.horizontal, UIScale.pt(6))
        }
        .padding(UIScale.pt(10))
        .frame(width: UIScale.pt(250))
    }

    private var summary: String {
        selection.count == options.count
            ? "All selected" : "\(selection.count) of \(options.count) selected"
    }

    private func apply(_ outcome: MultiSelectLogic.Outcome<String>) {
        selection = outcome.selection
        anchor = outcome.anchor
        if outcome.dismiss { dismiss() }
    }
}

private struct FilterSelectRow: View {
    let label: String
    let checked: Bool
    let actionLabel: String
    let dark: Bool
    let onToggle: () -> Void
    let onRowClick: (Bool, Bool) -> Void
    let onAction: () -> Void

    @State private var hovering = false

    var body: some View {
        HStack(spacing: UIScale.pt(8)) {
            Button(action: onToggle) { checkbox }
                .buttonStyle(.plain).pointerCursor()
            Button {
                let flags = NSApp.currentEvent?.modifierFlags ?? []
                onRowClick(
                    flags.contains(.command) || flags.contains(.control),
                    flags.contains(.shift))
            } label: {
                HStack(spacing: 0) {
                    Text(label)
                        .font(.system(size: UIScale.pt(11.5)))
                        .foregroundStyle(DashSkin.ink(dark))
                        .lineLimit(1)
                    Spacer(minLength: UIScale.pt(8))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain).pointerCursor()
            if hovering {
                Button(action: onAction) {
                    Text(actionLabel)
                        .font(.system(size: UIScale.pt(10)))
                        .foregroundStyle(DashSkin.inkSoft(dark))
                        .padding(.horizontal, UIScale.pt(6))
                        .padding(.vertical, UIScale.pt(2))
                        .background(
                            DashSkin.paper2(dark),
                            in: RoundedRectangle(cornerRadius: UIScale.pt(5))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: UIScale.pt(5))
                                .strokeBorder(DashSkin.line(dark), lineWidth: UIScale.pt(1))
                        )
                }
                .buttonStyle(.plain).pointerCursor()
            }
        }
        .padding(.horizontal, UIScale.pt(6))
        .padding(.vertical, UIScale.pt(4))
        .background(
            hovering ? DashSkin.inkFaint(dark).opacity(0.14) : Color.clear,
            in: RoundedRectangle(cornerRadius: UIScale.pt(6))
        )
        .onHover { hovering = $0 }
    }

    private var checkbox: some View {
        ZStack {
            RoundedRectangle(cornerRadius: UIScale.pt(4))
                .fill(checked ? DashSkin.accent(dark) : DashSkin.paper2(dark))
            RoundedRectangle(cornerRadius: UIScale.pt(4))
                .strokeBorder(
                    checked ? Color.clear : DashSkin.lineStrong(dark), lineWidth: UIScale.pt(1))
            if checked {
                Image(systemName: "checkmark")
                    .font(.system(size: UIScale.pt(8.5), weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: UIScale.pt(15), height: UIScale.pt(15))
    }
}
