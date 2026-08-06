import AppKit
import EdithKit
import SwiftUI

struct FinderIconView: View {
    @ObservedObject var model: FinderModel
    @Environment(\.colorScheme) private var scheme

    private var dark: Bool { scheme == .dark }

    var body: some View {
        ScrollView {
            LazyVGrid(
                columns: [
                    GridItem(
                        .adaptive(minimum: UIScale.pt(model.iconSize + 34)),
                        spacing: UIScale.pt(12))
                ], spacing: UIScale.pt(14)
            ) {
                ForEach(model.visibleEntries) { entry in
                    FinderIconCell(model: model, entry: entry, dark: dark)
                }
            }
            .padding(UIScale.pt(16))
        }
        .contentShape(Rectangle())
        .onTapGesture { model.selection = [] }
    }
}

private struct FinderIconCell: View {
    @ObservedObject var model: FinderModel
    let entry: RemoteFileEntry
    let dark: Bool
    @State private var hovering = false

    private var selected: Bool { model.selection.contains(entry.path) }

    var body: some View {
        VStack(spacing: UIScale.pt(6)) {
            Image(nsImage: FileIcons.icon(for: entry))
                .resizable()
                .interpolation(.high)
                .frame(width: UIScale.pt(model.iconSize), height: UIScale.pt(model.iconSize))
            label
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, UIScale.pt(6))
        .background(
            RoundedRectangle(cornerRadius: UIScale.pt(8))
                .fill(
                    selected
                        ? DashSkin.accent(dark).opacity(0.2)
                        : (hovering ? DashSkin.inkFaint(dark).opacity(0.08) : .clear))
        )
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .onTapGesture(count: 2) { model.open(entry) }
        .simultaneousGesture(
            TapGesture().modifiers(.command).onEnded { model.click(entry, modifiers: .command) }
        )
        .simultaneousGesture(
            TapGesture().modifiers(.shift).onEnded { model.click(entry, modifiers: .shift) }
        )
        .onTapGesture { model.click(entry, modifiers: []) }
        .onDrag { model.itemProvider(for: entry) }
        .contextMenu { FinderRowContextMenu(model: model, entry: entry) }
    }

    @ViewBuilder
    private var label: some View {
        if model.renaming == entry.path {
            TextField("", text: $model.renameText)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: UIScale.pt(11)))
                .frame(width: UIScale.pt(model.iconSize + 30))
                .onSubmit { Task { await model.commitRename() } }
        } else {
            Text(entry.name)
                .font(.system(size: UIScale.pt(11)))
                .foregroundStyle(DashSkin.ink(dark))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .padding(.horizontal, UIScale.pt(4))
                .background(
                    selected ? DashSkin.accent(dark).opacity(0.28) : .clear,
                    in: RoundedRectangle(cornerRadius: UIScale.pt(4)))
        }
    }
}

struct FinderListView: View {
    @ObservedObject var model: FinderModel
    @Environment(\.colorScheme) private var scheme

    private var dark: Bool { scheme == .dark }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.4)
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(model.visibleEntries) { entry in
                        FinderListRow(model: model, entry: entry, dark: dark)
                    }
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { model.selection = [] }
        }
    }

    private var header: some View {
        HStack(spacing: UIScale.pt(10)) {
            headerButton("Name", key: .name)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, UIScale.pt(30))
            headerButton("Date Modified", key: .modified)
                .frame(width: UIScale.pt(130), alignment: .trailing)
            headerButton("Size", key: .size)
                .frame(width: UIScale.pt(78), alignment: .trailing)
            headerButton("Kind", key: .kind)
                .frame(width: UIScale.pt(92), alignment: .trailing)
        }
        .padding(.horizontal, UIScale.pt(12))
        .padding(.vertical, UIScale.pt(5))
        .background(.thinMaterial)
    }

    private func headerButton(_ title: String, key: FileSortKey) -> some View {
        Button {
            if model.sortKey == key {
                model.sortAscending.toggle()
            } else {
                model.sortKey = key
                model.sortAscending = true
            }
        } label: {
            HStack(spacing: UIScale.pt(3)) {
                Text(title)
                    .font(.system(size: UIScale.pt(10), weight: .medium))
                if model.sortKey == key {
                    Image(systemName: model.sortAscending ? "chevron.up" : "chevron.down")
                        .font(.system(size: UIScale.pt(7), weight: .bold))
                }
            }
            .foregroundStyle(
                model.sortKey == key ? DashSkin.accent(dark) : DashSkin.inkFaint(dark)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .pointerCursor()
    }
}

private struct FinderListRow: View {
    @ObservedObject var model: FinderModel
    let entry: RemoteFileEntry
    let dark: Bool
    @State private var hovering = false

    private var selected: Bool { model.selection.contains(entry.path) }

    var body: some View {
        HStack(spacing: UIScale.pt(10)) {
            Image(nsImage: FileIcons.icon(for: entry))
                .resizable()
                .frame(width: UIScale.pt(16), height: UIScale.pt(16))
            nameLabel
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(entry.modified.map { $0.formatted(date: .abbreviated, time: .shortened) } ?? "—")
                .font(DashSkin.mono(10))
                .foregroundStyle(DashSkin.inkFaint(dark))
                .frame(width: UIScale.pt(130), alignment: .trailing)
            Text(entry.isDirectory ? "—" : ByteFormatter.string(entry.sizeBytes))
                .font(DashSkin.mono(10))
                .foregroundStyle(DashSkin.inkFaint(dark))
                .frame(width: UIScale.pt(78), alignment: .trailing)
            Text(entry.kindDescription)
                .font(.system(size: UIScale.pt(10.5)))
                .foregroundStyle(DashSkin.inkFaint(dark))
                .lineLimit(1)
                .frame(width: UIScale.pt(92), alignment: .trailing)
        }
        .padding(.horizontal, UIScale.pt(12))
        .padding(.vertical, UIScale.pt(4))
        .background(
            selected
                ? DashSkin.accent(dark).opacity(0.22)
                : (hovering ? DashSkin.inkFaint(dark).opacity(0.07) : .clear)
        )
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .onTapGesture(count: 2) { model.open(entry) }
        .simultaneousGesture(
            TapGesture().modifiers(.command).onEnded { model.click(entry, modifiers: .command) }
        )
        .simultaneousGesture(
            TapGesture().modifiers(.shift).onEnded { model.click(entry, modifiers: .shift) }
        )
        .onTapGesture { model.click(entry, modifiers: []) }
        .onDrag { model.itemProvider(for: entry) }
        .contextMenu { FinderRowContextMenu(model: model, entry: entry) }
    }

    @ViewBuilder
    private var nameLabel: some View {
        if model.renaming == entry.path {
            TextField("", text: $model.renameText)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: UIScale.pt(12)))
                .onSubmit { Task { await model.commitRename() } }
        } else {
            HStack(spacing: UIScale.pt(5)) {
                Text(entry.name)
                    .font(.system(size: UIScale.pt(12.5)))
                    .foregroundStyle(DashSkin.ink(dark))
                    .lineLimit(1)
                if let target = entry.linkTarget {
                    Text("→ \(target)")
                        .font(DashSkin.mono(9.5))
                        .foregroundStyle(DashSkin.inkFaint(dark))
                        .lineLimit(1)
                }
            }
        }
    }
}

struct QuickLookOverlay: View {
    @ObservedObject var model: FinderModel
    @Environment(\.colorScheme) private var scheme

    private var dark: Bool { scheme == .dark }

    private var entry: RemoteFileEntry? {
        model.visibleEntries.first { $0.path == model.quickLookPath }
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture { model.quickLookPath = nil }
            VStack(spacing: 0) {
                HStack(spacing: UIScale.pt(10)) {
                    Button {
                        model.quickLookPath = nil
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .buttonStyle(HoverButtonStyle())
                    Text(entry?.name ?? "")
                        .font(.system(size: UIScale.pt(12.5), weight: .medium))
                        .foregroundStyle(DashSkin.ink(dark))
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    if let entry, !entry.isDirectory {
                        Text(ByteFormatter.string(entry.sizeBytes))
                            .font(DashSkin.mono(10.5))
                            .foregroundStyle(DashSkin.inkFaint(dark))
                    }
                    Button {
                        model.moveSelection(by: -1, extend: false)
                    } label: {
                        Image(systemName: "chevron.up")
                    }
                    .buttonStyle(HoverButtonStyle())
                    Button {
                        model.moveSelection(by: 1, extend: false)
                    } label: {
                        Image(systemName: "chevron.down")
                    }
                    .buttonStyle(HoverButtonStyle())
                }
                .padding(UIScale.pt(12))
                Divider()
                FilePreviewPane(entry: entry, session: model.session)
            }
            .frame(width: UIScale.pt(660), height: UIScale.pt(460))
            .background(DashSkin.paper2(dark), in: RoundedRectangle(cornerRadius: UIScale.pt(14)))
            .overlay {
                RoundedRectangle(cornerRadius: UIScale.pt(14))
                    .strokeBorder(DashSkin.line(dark))
            }
            .shadow(color: .black.opacity(0.4), radius: UIScale.pt(30), y: 12)
        }
    }
}
