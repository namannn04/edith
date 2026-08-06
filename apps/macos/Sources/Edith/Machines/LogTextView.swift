import AppKit
import EdithKit
import SwiftUI

struct LogPalette {
    var text: NSColor
    var stderr: NSColor
    var timestamp: NSColor
    var background: NSColor
}

struct LogDocument: Equatable {
    var lines: [DockerLogLine]
    var showTimestamps: Bool
    var wraps: Bool
    var fontSize: Double
}

final class LogTextViewController: NSViewController {
    private let scrollView = NSScrollView()
    private let textView = NSTextView()
    private var lastRenderedCount = 0

    var onScrolledAwayFromBottom: ((Bool) -> Void)?

    override func loadView() {
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = true
        textView.isRichText = false
        textView.usesFindBar = true
        textView.isIncrementalSearchingEnabled = true
        textView.textContainerInset = NSSize(width: 12, height: 10)
        textView.autoresizingMask = [.width]
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false

        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = false
        scrollView.drawsBackground = true
        view = scrollView

        NotificationCenter.default.addObserver(
            self, selector: #selector(didScroll),
            name: NSView.boundsDidChangeNotification,
            object: scrollView.contentView)
        scrollView.contentView.postsBoundsChangedNotifications = true
    }

    @objc private func didScroll() {
        onScrolledAwayFromBottom?(!isPinnedToBottom)
    }

    private var isPinnedToBottom: Bool {
        let visible = scrollView.contentView.bounds
        let total = textView.bounds.height
        return visible.maxY >= total - 24
    }

    func apply(_ document: LogDocument, palette: LogPalette, follow: Bool) {
        let wasPinned = isPinnedToBottom
        let selected = textView.selectedRange()
        let hasSelection = selected.length > 0

        configureWrapping(document.wraps)
        textView.backgroundColor = palette.background
        scrollView.backgroundColor = palette.background

        let body = NSMutableAttributedString()
        let font = NSFont.monospacedSystemFont(ofSize: document.fontSize, weight: .regular)
        for line in document.lines {
            if document.showTimestamps, let stamp = line.timestamp {
                body.append(
                    NSAttributedString(
                        string: stamp + "  ",
                        attributes: [.font: font, .foregroundColor: palette.timestamp]))
            }
            body.append(
                NSAttributedString(
                    string: line.text + "\n",
                    attributes: [
                        .font: font,
                        .foregroundColor: line.isStderr ? palette.stderr : palette.text,
                    ]))
        }

        textView.textStorage?.setAttributedString(body)
        lastRenderedCount = document.lines.count

        if hasSelection, selected.location + selected.length <= body.length {
            textView.setSelectedRange(selected)
        } else if follow, wasPinned {
            textView.scrollToEndOfDocument(nil)
        }
    }

    private func configureWrapping(_ wraps: Bool) {
        guard let container = textView.textContainer else { return }
        if wraps {
            textView.isHorizontallyResizable = false
            container.widthTracksTextView = true
            container.containerSize = NSSize(
                width: scrollView.contentSize.width, height: CGFloat.greatestFiniteMagnitude)
            scrollView.hasHorizontalScroller = false
            textView.frame.size.width = scrollView.contentSize.width
        } else {
            textView.isHorizontallyResizable = true
            container.widthTracksTextView = false
            container.containerSize = NSSize(
                width: CGFloat.greatestFiniteMagnitude,
                height: CGFloat.greatestFiniteMagnitude)
            scrollView.hasHorizontalScroller = true
        }
    }

    func copyAll() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(textView.string, forType: .string)
    }

    func scrollToEnd() {
        textView.scrollToEndOfDocument(nil)
    }
}

struct LogTextView: NSViewControllerRepresentable {
    let document: LogDocument
    let palette: LogPalette
    let follow: Bool
    var onScrolledAwayFromBottom: (Bool) -> Void = { _ in }

    func makeNSViewController(context: Context) -> LogTextViewController {
        let controller = LogTextViewController()
        controller.onScrolledAwayFromBottom = onScrolledAwayFromBottom
        return controller
    }

    func updateNSViewController(_ controller: LogTextViewController, context: Context) {
        controller.onScrolledAwayFromBottom = onScrolledAwayFromBottom
        controller.apply(document, palette: palette, follow: follow)
    }
}
