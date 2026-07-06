import AppKit
import SwiftUI

struct ProjectDrilldownView: View {
    @ObservedObject var model: DashboardModel
    let dark: Bool

    private static let chatsPerGroup = 20
    private static let numWidths: [CGFloat] = [95, 85, 55, 72, 70, 60]

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            toggleButton
            if model.projListOpen {
                headerRow
                    .padding(.top, 8)
                Rectangle().fill(DashSkin.line(dark)).frame(height: 1)
                ForEach(model.projectTree) { proj in
                    projectRows(proj)
                }
            }
        }
    }

    private var toggleButton: some View {
        Button {
            withAnimation(.easeOut(duration: 0.15)) { model.projListOpen.toggle() }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: model.projListOpen ? "chevron.down" : "chevron.right")
                    .font(.system(size: 8, weight: .semibold))
                Text(
                    "\(model.projListOpen ? "Hide" : "Show") projects (\(model.projectTree.count))"
                )
                .font(DashSkin.mono(11))
            }
            .foregroundStyle(DashSkin.inkSoft(dark))
        }
        .buttonStyle(.plain)
    }

    private var headerRow: some View {
        HStack(spacing: 8) {
            sortHeader("Project", .name, width: nil)
            sortHeader("Tokens", .tokens, width: Self.numWidths[0])
            sortHeader("Cost", .cost, width: Self.numWidths[1])
            sortHeader("% share", .share, width: Self.numWidths[2])
            sortHeader("Days active", .days, width: Self.numWidths[3])
            sortHeader("Time spent", .dur, width: Self.numWidths[4])
            sortHeader("Last used", .lastActive, width: Self.numWidths[5])
        }
        .font(DashSkin.mono(10, weight: .semibold))
        .foregroundStyle(DashSkin.inkFaint(dark))
        .padding(.vertical, 4)
    }

    private func sortHeader(_ title: String, _ key: ProjSortKey, width: CGFloat?) -> some View {
        Button {
            if model.projSortKey == key {
                model.projSortAscending.toggle()
            } else {
                model.projSortKey = key
                model.projSortAscending = key == .name
            }
        } label: {
            HStack(spacing: 2) {
                Text(title)
                if model.projSortKey == key {
                    Image(systemName: model.projSortAscending ? "chevron.up" : "chevron.down")
                        .font(.system(size: 7))
                }
            }
            .frame(width: width, alignment: width == nil ? .leading : .trailing)
            .frame(maxWidth: width == nil ? .infinity : nil, alignment: .leading)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder private func projectRows(_ p: ProjTreeRow) -> some View {
        let open = model.projExpanded.contains(p.id)
        treeRow(
            depth: 0, expandable: p.expandable, open: open, icon: "folder",
            badge: p.nestedCount, label: p.name, values: p, chatId: nil,
            tint: DashSkin.ink(dark), expandKey: p.id)
        if open {
            chatRows(p.chats, depth: 1)
            ForEach(p.worktrees) { wt in
                worktreeRows(wt)
            }
        }
        Rectangle().fill(DashSkin.line(dark).opacity(0.5)).frame(height: 1)
    }

    @ViewBuilder private func worktreeRows(_ wt: ProjWorktree) -> some View {
        let open = model.projExpanded.contains(wt.id)
        treeRow(
            depth: 1, expandable: !wt.chats.isEmpty, open: open, icon: "arrow.triangle.branch",
            badge: wt.chats.count, label: wt.name, values: wt, chatId: nil,
            tint: DashSkin.ink(dark), expandKey: wt.id)
        if open {
            chatRows(wt.chats, depth: 2)
        }
    }

    @ViewBuilder private func chatRows(_ chats: [ProjChat], depth: Int) -> some View {
        ForEach(chats.prefix(Self.chatsPerGroup)) { c in
            treeRow(
                depth: depth, expandable: false, open: false, icon: "message",
                badge: 0, label: c.title, values: c, chatId: c.id,
                tint: DashSkin.inkSoft(dark), expandKey: nil)
        }
        if chats.count > Self.chatsPerGroup {
            moreRow(Array(chats.dropFirst(Self.chatsPerGroup)), depth: depth)
        }
    }

    private func moreRow(_ rest: [ProjChat], depth: Int) -> some View {
        let days = rest.reduce(into: Set<String>()) { $0.formUnion($1.daySet) }
        return HStack(spacing: 8) {
            nameCell(
                depth: depth, expandable: false, open: false, icon: "message", badge: 0,
                label: "+\(rest.count) more chats", chatId: nil)
            numCell(DashFmt.tokensFull(rest.reduce(0) { $0 + $1.tokens }), 0)
            numCell(DashFmt.usdLong(rest.reduce(0) { $0 + $1.cost }), 1)
            numCell(DashFmt.pct(rest.reduce(0) { $0 + $1.share }), 2)
            numCell("\(days.count)", 3)
            numCell(DashFmt.duration(rest.reduce(0) { $0 + $1.dur }), 4)
            numCell("", 5)
        }
        .foregroundStyle(DashSkin.inkFaint(dark))
        .padding(.vertical, 4)
    }

    @ViewBuilder private func treeRow(
        depth: Int, expandable: Bool, open: Bool, icon: String, badge: Int,
        label: String, values: some ProjSortable, chatId: String?, tint: Color,
        expandKey: String?
    ) -> some View {
        let row = HStack(spacing: 8) {
            nameCell(
                depth: depth, expandable: expandable, open: open, icon: icon, badge: badge,
                label: label, chatId: chatId)
            numCell(DashFmt.tokensFull(values.tokens), 0)
            numCell(DashFmt.usdLong(values.cost), 1)
            numCell(DashFmt.pct(values.share), 2)
            numCell("\(values.days)", 3)
            numCell(DashFmt.duration(values.dur), 4)
            numCell(values.lastActive.isEmpty ? "—" : DashFmt.dateShort(values.lastActive), 5)
        }
        .foregroundStyle(tint)
        .padding(.vertical, 4)
        if let chatId, !chatId.isEmpty {
            row.contextMenu {
                Button("Copy chat ID") { copyToPasteboard(chatId) }
            }
        } else {
            row
                .contentShape(Rectangle())
                .onTapGesture {
                    guard let expandKey, expandable else { return }
                    withAnimation(.easeOut(duration: 0.12)) {
                        if model.projExpanded.contains(expandKey) {
                            model.projExpanded.remove(expandKey)
                        } else {
                            model.projExpanded.insert(expandKey)
                        }
                    }
                }
        }
    }

    private func nameCell(
        depth: Int, expandable: Bool, open: Bool, icon: String, badge: Int,
        label: String, chatId: String?
    ) -> some View {
        HStack(spacing: 5) {
            Image(systemName: "chevron.right")
                .font(.system(size: 8, weight: .semibold))
                .rotationEffect(.degrees(open ? 90 : 0))
                .opacity(expandable ? 1 : 0)
                .frame(width: 10)
            iconView(icon, badge: badge, chatId: chatId)
            Text(label)
                .font(.system(size: 11))
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .padding(.leading, CGFloat(depth) * 20)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder private func iconView(_ icon: String, badge: Int, chatId: String?) -> some View {
        let img = ZStack(alignment: .topTrailing) {
            Image(systemName: icon).font(.system(size: 10))
            if badge > 0 {
                Text(badge > 99 ? "99+" : "\(badge)")
                    .font(.system(size: 7, weight: .semibold))
                    .offset(x: 7, y: -4)
            }
        }
        .frame(width: 16, height: 14, alignment: .leading)
        if let chatId, !chatId.isEmpty {
            Button {
                copyToPasteboard(chatId)
            } label: {
                img
            }
            .buttonStyle(.plain)
        } else {
            img
        }
    }

    private func numCell(_ text: String, _ column: Int) -> some View {
        Text(text)
            .font(DashSkin.mono(11))
            .lineLimit(1)
            .frame(width: Self.numWidths[column], alignment: .trailing)
    }

    private func copyToPasteboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}
