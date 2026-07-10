import CoreGraphics

enum NotchGeometry {
    static let topFlareRadius: CGFloat = 6
    static let fallbackSize = CGSize(width: 150, height: 28)
    static let expandedWidth: CGFloat = 580
    static let expandedHeaderBand: CGFloat = 40
    static let expandedMaxSize = CGSize(width: expandedWidth, height: 412)

    static func expandedShapeSize(tab: NotchTab, hasMusic: Bool, notchHeight: CGFloat) -> CGSize {
        let content: CGFloat =
            switch tab {
            case .home: hasMusic ? 158 : 148
            case .files: 134
            case .clipboard, .audio: 162
            case .camera: 332
            }
        return CGSize(width: expandedWidth, height: notchHeight + expandedHeaderBand + content)
    }

    static func collapsedSize(
        screenWidth: CGFloat,
        leftAreaWidth: CGFloat?,
        rightAreaWidth: CGFloat?,
        safeAreaTop: CGFloat
    ) -> CGSize {
        guard safeAreaTop > 0, let left = leftAreaWidth, let right = rightAreaWidth else {
            return fallbackSize
        }
        let width = screenWidth - left - right
        guard width > 1 else { return fallbackSize }
        return CGSize(width: width, height: safeAreaTop)
    }

    static func origin(screenFrame: CGRect, panelSize: CGSize) -> CGPoint {
        CGPoint(x: screenFrame.midX - panelSize.width / 2, y: screenFrame.maxY - panelSize.height)
    }

    static let openMargin: CGFloat = 6
    static let keepOpenMargin: CGFloat = 24
    static let panelPadding = CGSize(width: 24, height: 10)
    static let hoverGrowScale: CGFloat = 1.06

    static func panelSize(forShape shape: CGSize) -> CGSize {
        CGSize(width: shape.width + panelPadding.width, height: shape.height + panelPadding.height)
    }

    static func shapeSize(inPanel panel: CGSize) -> CGSize {
        CGSize(
            width: max(1, panel.width - panelPadding.width),
            height: max(1, panel.height - panelPadding.height))
    }

    static let expandedTopRadius: CGFloat = 10
    static let expandedBottomRadius: CGFloat = 22
    static let alertBottomRadius: CGFloat = 20
    static let collapsedBottomRadius: CGFloat = 12

    static let musicWingWidth: CGFloat = 42
    static let alertDropSize = CGSize(width: 330, height: 78)

    static func collapsedSize(base: CGSize, hasLiveActivity: Bool) -> CGSize {
        guard hasLiveActivity else { return base }
        return CGSize(width: base.width + 2 * musicWingWidth, height: base.height)
    }

    static func proximity(
        point: CGPoint,
        collapsedFrame: CGRect,
        expandedFrame: CGRect,
        openMargin: CGFloat = openMargin,
        keepOpenMargin: CGFloat = keepOpenMargin
    ) -> NotchProximity {
        if collapsedFrame.insetBy(dx: -openMargin, dy: -openMargin).contains(point) {
            return .open
        }
        if expandedFrame.insetBy(dx: -keepOpenMargin, dy: -keepOpenMargin).contains(point) {
            return .keepOpen
        }
        return .outside
    }

    static func hardwareNotchRect(in panelSize: CGSize, collapsedSize: CGSize) -> CGRect {
        let width = min(collapsedSize.width, panelSize.width)
        let height = min(collapsedSize.height, panelSize.height)
        return CGRect(
            x: (panelSize.width - width) / 2, y: panelSize.height - height,
            width: width, height: height)
    }

    static let itemCell = CGSize(width: 78, height: 70)

    static func itemPosition(stored: CGPoint?, index: Int, in size: CGSize) -> CGPoint {
        let point = stored ?? defaultItemPosition(index: index, in: size)
        return CGPoint(
            x: min(max(point.x, itemCell.width / 2), size.width - itemCell.width / 2),
            y: min(max(point.y, itemCell.height / 2), size.height - itemCell.height / 2))
    }

    static func defaultItemPosition(index: Int, in size: CGSize) -> CGPoint {
        let columns = max(1, Int((size.width - 24) / itemCell.width))
        let column = index % columns
        let row = index / columns
        return CGPoint(
            x: 12 + itemCell.width * (CGFloat(column) + 0.5),
            y: 10 + itemCell.height * (CGFloat(row) + 0.5))
    }
}
