import AppKit
import EdithKit
import EventKit
import SwiftUI

struct NotchShelfContentView: View {
    @ObservedObject var controller: NotchShelfController
    var collapsedBase: CGSize = NotchGeometry.fallbackSize
    var isBuiltin = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var tabPill

    var body: some View {
        GeometryReader { geo in
            let shape = shapeSize
            ZStack {
                NotchShape(topRadius: topRadius, bottomRadius: bottomRadius)
                    .fill(.black)
                if controller.isExpanded {
                    expanded.transition(contentTransition)
                } else if isBuiltin, let alert = controller.currentAlert {
                    NotchAlertDropView(alert: alert, controller: controller)
                        .transition(contentTransition)
                } else {
                    collapsed.transition(.opacity)
                }
            }
            .frame(width: shape.width, height: shape.height)
            .scaleEffect(hoverScale, anchor: .top)
            .animation(glide, value: controller.isExpanded)
            .animation(glide, value: controller.currentAlert)
            .animation(glide, value: controller.nowPlaying == nil)
            .animation(glide, value: controller.collapsedHover)
            .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
            .onContinuousHover { phase in
                switch phase {
                case .active(let point):
                    controller.hoverChanged(hoverRect(in: geo.size).contains(point))
                case .ended:
                    controller.hoverChanged(false)
                }
            }
        }
    }

    private var shapeSize: CGSize {
        if controller.isExpanded { return NotchGeometry.expandedSize }
        if isBuiltin, controller.currentAlert != nil { return NotchGeometry.alertDropSize }
        return NotchGeometry.collapsedSize(
            base: collapsedBase, hasLiveActivity: controller.nowPlaying != nil)
    }

    private func hoverRect(in panel: CGSize) -> CGRect {
        let shape = shapeSize
        return CGRect(
            x: (panel.width - shape.width) / 2, y: 0, width: shape.width, height: shape.height
        )
        .insetBy(dx: -NotchGeometry.openMargin, dy: -NotchGeometry.openMargin)
    }

    private var hoverScale: CGFloat {
        guard !reduceMotion, controller.collapsedHover, !controller.isExpanded,
            controller.currentAlert == nil
        else { return 1 }
        return NotchGeometry.hoverGrowScale
    }

    private var topRadius: CGFloat {
        controller.isExpanded || (isBuiltin && controller.currentAlert != nil)
            ? NotchGeometry.expandedTopRadius : 0
    }

    private var bottomRadius: CGFloat {
        if isBuiltin, controller.currentAlert != nil, !controller.isExpanded { return 22 }
        return controller.isExpanded
            ? NotchGeometry.expandedBottomRadius : NotchGeometry.collapsedBottomRadius
    }

    private var glide: Animation {
        reduceMotion
            ? .easeInOut(duration: 0.2) : .spring(response: 0.36, dampingFraction: 0.86)
    }

    private var contentTransition: AnyTransition {
        guard !reduceMotion else { return .opacity }
        return .asymmetric(
            insertion: AnyTransition.modifier(
                active: NotchContentFade(progress: 0), identity: NotchContentFade(progress: 1)
            ).animation(.easeOut(duration: 0.25).delay(0.06)),
            removal: .opacity.animation(.easeOut(duration: 0.1)))
    }

    @ViewBuilder private var collapsed: some View {
        if let track = controller.nowPlaying {
            NotchMusicWings(controller: controller, track: track)
        } else if !controller.items.isEmpty {
            HStack(spacing: 3) {
                Image(systemName: "tray.full.fill")
                    .font(.system(size: 8.5, weight: .semibold))
                Text("\(controller.items.count)")
                    .font(.system(size: 9, weight: .semibold))
            }
            .foregroundStyle(.white.opacity(0.7))
        }
    }

    private var expanded: some View {
        VStack(spacing: 6) {
            header
            tabContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var header: some View {
        HStack(spacing: 0) {
            HStack(spacing: 4) {
                ForEach(visibleTabs, id: \.self) { tab in
                    iconTab(tab)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Spacer(minLength: 0)
                .frame(width: collapsedBase.width)
            Button {
                MainApp.openDashboard()
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 11.5))
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(width: 32, height: 22)
                    .background(Color.white.opacity(0.07), in: Capsule())
            }
            .buttonStyle(.plain).pointerCursor()
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .frame(height: max(30, collapsedBase.height))
        .animation(
            reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.85),
            value: controller.activeTab)
    }

    private func iconTab(_ tab: NotchTab) -> some View {
        let active = controller.activeTab == tab
        return Button {
            controller.selectTab(tab)
        } label: {
            Image(systemName: tab.icon)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(active ? Color.black : Color.white.opacity(0.7))
                .frame(width: 32, height: 22)
                .background {
                    if active {
                        Capsule()
                            .fill(Color.white.opacity(0.92))
                            .matchedGeometryEffect(id: "activeTab", in: tabPill)
                    } else {
                        Capsule().fill(Color.white.opacity(0.07))
                    }
                }
        }
        .buttonStyle(.plain).pointerCursor()
        .help(tab.title)
    }

    private var visibleTabs: [NotchTab] {
        let mixerOn = SharedDefaults.store.bool(forKey: "notchAudioMixerEnabled")
        return NotchTab.allCases.filter { $0 != .audio || mixerOn }
    }

    @ViewBuilder private var tabContent: some View {
        switch controller.activeTab {
        case .home: NotchHomeTab(controller: controller)
        case .files: filesCanvas
        case .clipboard: NotchClipboardTab(controller: controller)
        case .audio: NotchAudioTab()
        case .camera: NotchCameraTab()
        }
    }

    private var filesCanvas: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                if controller.items.isEmpty {
                    Text("Drop files here to park them")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.6))
                        .frame(width: geo.size.width, height: geo.size.height)
                } else {
                    ForEach(Array(controller.items.enumerated()), id: \.element.id) {
                        index, item in
                        ShelfItemView(item: item, controller: controller, canvasSize: geo.size)
                            .position(
                                NotchGeometry.itemPosition(
                                    stored: controller.livePositions[item.id] ?? item.position,
                                    index: index, in: geo.size))
                    }
                }
            }
            .coordinateSpace(name: "shelfCanvas")
        }
    }
}

private struct NotchHomeTab: View {
    @ObservedObject var controller: NotchShelfController

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            if let track = controller.nowPlaying {
                NotchNowPlayingCard(controller: controller, track: track)
                sideColumn.frame(width: 176)
            } else if nextEvent != nil || controller.usageStore != nil {
                if let event = nextEvent { eventCard(event) }
                if let usage = controller.usageStore { ringsCard(usage) }
            } else {
                Text("Nothing to show yet")
                    .font(.system(size: 12)).foregroundStyle(.white.opacity(0.4))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(.horizontal, 12).padding(.bottom, 12)
    }

    private var sideColumn: some View {
        VStack(spacing: 10) {
            if let event = nextEvent { eventCard(event) }
            if let usage = controller.usageStore { ringsCard(usage) }
            Spacer(minLength: 0)
        }
    }

    private var nextEvent: EKEvent? {
        let upcoming = (controller.calendarStore?.events ?? [])
            .filter { ($0.startDate ?? .distantPast) > Date() }
            .sorted { ($0.startDate ?? .distantPast) < ($1.startDate ?? .distantPast) }
        return upcoming.first { !$0.isAllDay } ?? upcoming.first
    }

    private func ringsCard(_ usage: UsageStore) -> some View {
        NotchUsageRings(usage: usage)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14))
    }

    private func eventCard(_ event: EKEvent) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("NEXT UP")
                .font(.system(size: 8.5, weight: .bold)).tracking(0.8)
                .foregroundStyle(.white.opacity(0.4))
            Text(event.title ?? "Event")
                .font(.system(size: 12.5, weight: .semibold)).foregroundStyle(.white).lineLimit(1)
            Text(eventTimeLabel(event))
                .font(.system(size: 10.5)).foregroundStyle(.white.opacity(0.55))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14))
    }

    private func eventTimeLabel(_ event: EKEvent) -> String {
        guard let start = event.startDate else { return "" }
        let day =
            Calendar.current.isDateInToday(start)
            ? "" : start.formatted(.dateTime.weekday(.abbreviated)) + " "
        if event.isAllDay { return day + "All day" }
        return day + start.formatted(date: .omitted, time: .shortened)
    }
}

private struct NotchNowPlayingCard: View {
    @ObservedObject var controller: NotchShelfController
    let track: NotchNowPlaying

    var body: some View {
        HStack(spacing: 12) {
            artwork
            VStack(alignment: .leading, spacing: 7) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(track.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white).lineLimit(1)
                    if !track.artist.isEmpty {
                        Text(track.artist)
                            .font(.system(size: 12)).foregroundStyle(.white.opacity(0.55))
                            .lineLimit(1)
                    }
                }
                if controller.nowPlayingSeekable {
                    NotchSeekBar(controller: controller)
                }
                HStack(spacing: 18) {
                    control("backward.fill", 14) { controller.nowPlayingPrevious() }
                    control(track.isPlaying ? "pause.fill" : "play.fill", 18) {
                        controller.nowPlayingPlayPause()
                    }
                    control("forward.fill", 14) { controller.nowPlayingNext() }
                    Spacer(minLength: 8)
                    volumeControl
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(12)
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14))
    }

    private var artwork: some View {
        Group {
            if let image = controller.nowPlayingArtwork {
                Image(nsImage: image).resizable().aspectRatio(contentMode: .fill)
            } else {
                Image(systemName: "music.note")
                    .font(.system(size: 20)).foregroundStyle(.white.opacity(0.5))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.white.opacity(0.08))
            }
        }
        .frame(width: 54, height: 54)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.4), radius: 6, y: 3)
    }

    private var volumeControl: some View {
        HStack(spacing: 5) {
            Image(systemName: "speaker.fill")
                .font(.system(size: 9)).foregroundStyle(.white.opacity(0.5))
            Slider(
                value: Binding(
                    get: { controller.nowPlayingVolume },
                    set: { controller.setNowPlayingVolume($0) }), in: 0...1
            )
            .controlSize(.mini).frame(width: 58).tint(.white.opacity(0.85))
        }
    }

    private func control(_ name: String, _ size: CGFloat, _ action: @escaping () -> Void)
        -> some View
    {
        Button(action: action) {
            Image(systemName: name)
                .font(.system(size: size, weight: .medium)).foregroundStyle(.white)
        }
        .buttonStyle(.plain).pointerCursor()
    }
}

private struct NotchSeekBar: View {
    @ObservedObject var controller: NotchShelfController
    @State private var dragFraction: Double?

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.15)).frame(height: 3)
                TimelineView(.periodic(from: MusicTick.epoch, by: 0.5)) { _ in
                    let fraction = dragFraction ?? controller.nowPlayingProgress()
                    Capsule().fill(.white.opacity(0.85))
                        .frame(width: max(3, width * min(1, fraction)), height: 3)
                }
            }
            .frame(height: 10)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { dragFraction = min(max($0.location.x / width, 0), 1) }
                    .onEnded { value in
                        controller.nowPlayingSeek(min(max(value.location.x / width, 0), 1))
                        dragFraction = nil
                    }
            )
        }
        .frame(height: 10)
    }
}

private struct NotchUsageRings: View {
    @ObservedObject var usage: UsageStore

    var body: some View {
        HStack(spacing: 22) {
            ring("Session", usage.session?.percent)
            ring("Week", usage.week?.percent)
        }
    }

    private func ring(_ label: String, _ percent: Double?) -> some View {
        let value = percent ?? 0
        return VStack(spacing: 3) {
            ZStack {
                Circle().stroke(.white.opacity(0.12), lineWidth: 3.5)
                Circle()
                    .trim(from: 0, to: min(1, value / 100))
                    .stroke(color(value), style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(Int(value.rounded()))")
                    .font(.system(size: 10.5, weight: .semibold)).foregroundStyle(.white)
            }
            .frame(width: 34, height: 34)
            Text(label).font(.system(size: 9.5)).foregroundStyle(.white.opacity(0.6))
        }
    }

    private func color(_ percent: Double) -> Color {
        if percent >= 85 { return Color(red: 0.88, green: 0.4, blue: 0.31) }
        if percent >= 60 { return Color(red: 0.88, green: 0.66, blue: 0.25) }
        return Color(red: 0.3, green: 0.77, blue: 0.49)
    }
}

private struct NotchClipboardTab: View {
    @ObservedObject var controller: NotchShelfController

    var body: some View {
        if let store = controller.clipboardStore {
            NotchClipboardList(store: store, controller: controller)
        } else {
            Text("Clipboard history is off")
                .font(.system(size: 12)).foregroundStyle(.white.opacity(0.5))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private struct NotchClipboardList: View {
    @ObservedObject var store: ClipboardStore
    let controller: NotchShelfController

    var body: some View {
        ScrollView {
            VStack(spacing: 6) {
                ForEach(store.entries.prefix(8)) { entry in
                    Button {
                        controller.copyClipboardEntry(entry)
                    } label: {
                        HStack(spacing: 8) {
                            Text(entry.preview ?? "Non-text item")
                                .font(.system(size: 12)).foregroundStyle(.white.opacity(0.85))
                                .lineLimit(1)
                            Spacer(minLength: 0)
                            if entry.pinned {
                                Image(systemName: "pin.fill")
                                    .font(.system(size: 9)).foregroundStyle(.white.opacity(0.5))
                            }
                        }
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain).pointerCursor()
                }
            }
            .padding(.horizontal, 12).padding(.bottom, 12)
        }
    }
}

private struct NotchAlertDropView: View {
    let alert: NotchAlert
    @ObservedObject var controller: NotchShelfController

    var body: some View {
        let tint = Color(hex: alert.tint)
        return HStack(spacing: 12) {
            Image(systemName: alert.icon)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(tint)
                .frame(width: 34, height: 34)
                .background(tint.opacity(0.2), in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 2) {
                Text(alert.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white).lineLimit(1)
                if let subtitle = alert.subtitle {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.6)).lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.top, 34)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        .contentShape(Rectangle())
        .onHover { controller.alertHover($0) }
        .onTapGesture { controller.dismissAlert() }
    }
}

extension Color {
    fileprivate init(hex: String) {
        let cleaned = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        self.init(
            red: Double((value >> 16) & 0xff) / 255,
            green: Double((value >> 8) & 0xff) / 255,
            blue: Double(value & 0xff) / 255)
    }
}

struct NotchContentFade: ViewModifier, Animatable {
    var progress: Double

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        content
            .opacity(progress)
            .blur(radius: (1 - progress) * 8)
            .offset(y: (1 - progress) * -8)
    }
}

private struct NotchMusicWings: View {
    @ObservedObject var controller: NotchShelfController
    let track: NotchNowPlaying
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 0) {
            artwork
                .frame(width: NotchGeometry.musicWingWidth)
            Spacer(minLength: 0)
            PlaybackWave(playing: track.isPlaying, color: .white.opacity(0.85), barCount: 4)
                .frame(width: NotchGeometry.musicWingWidth)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var sourceKey: String { String(describing: track.source) }

    private var artwork: some View {
        ZStack {
            wingIcon
                .id(sourceKey)
                .transition(
                    reduceMotion
                        ? .opacity
                        : .asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .opacity))
        }
        .animation(
            reduceMotion
                ? .easeInOut(duration: 0.2) : .spring(response: 0.5, dampingFraction: 0.9),
            value: sourceKey
        )
        .clipped()
    }

    @ViewBuilder private var wingIcon: some View {
        if let image = controller.nowPlayingArtwork {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 20, height: 20)
                .clipShape(RoundedRectangle(cornerRadius: 4))
        } else {
            Image(systemName: "music.note")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.8))
        }
    }
}

private struct ShelfItemView: View {
    let item: ShelfItem
    @ObservedObject var controller: NotchShelfController
    let canvasSize: CGSize
    @State private var handedOffToSystemDrag = false
    @State private var thumbnail: NSImage?

    var body: some View {
        VStack(spacing: 4) {
            Image(
                nsImage: thumbnail
                    ?? NSWorkspace.shared.icon(forFile: controller.fileURL(for: item).path)
            )
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 38, height: 38)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            Text(item.name)
                .font(.system(size: 10))
                .foregroundStyle(.white)
                .lineLimit(1)
                .frame(width: 64)
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.white.opacity(controller.selectedIDs.contains(item.id) ? 0.2 : 0))
        )
        .contentShape(Rectangle())
        .gesture(moveOrDragOut)
        .onTapGesture {
            if NSEvent.modifierFlags.contains(.shift) {
                controller.toggleSelection(item)
            } else {
                controller.open(item)
            }
        }
        .contextMenu {
            Button("Open") { controller.open(item) }
            Button("Reveal in Finder") { controller.reveal(item) }
            Button("Share") { controller.share(item) }
            Button("Delete", role: .destructive) { controller.remove(item) }
        }
        .task(id: item.name) {
            thumbnail = await ShelfThumbnails.thumbnail(for: controller.fileURL(for: item))
        }
    }

    private var moveOrDragOut: some Gesture {
        DragGesture(minimumDistance: 3, coordinateSpace: .named("shelfCanvas"))
            .onChanged { value in
                guard !handedOffToSystemDrag else { return }
                if CGRect(origin: .zero, size: canvasSize).contains(value.location) {
                    controller.canvasDrag(item, to: value.location, in: canvasSize)
                } else {
                    handedOffToSystemDrag = true
                    controller.beginExternalDrag(of: item)
                }
            }
            .onEnded { _ in
                handedOffToSystemDrag = false
                controller.endCanvasDrag()
            }
    }
}
