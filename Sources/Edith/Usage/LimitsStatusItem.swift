import AppKit

/// Second menu bar item: "S 42  W 67", each number tinted by its own risk.
/// Clicking it toggles the main Edith panel. Created/destroyed by UsageStore
/// from the "limitsInMenuBar" setting.
@MainActor
final class LimitsStatusItem {
    /// This item's own button. The App.swift lookups exclude ITS window when
    /// hunting for the MenuBarExtra's window - resolved at lookup time, never
    /// captured, because the button has no window until the bar installs it.
    /// nonisolated(unsafe): the lookups are plain non-isolated globals; all of
    /// this runs on the main thread.
    nonisolated(unsafe) static private(set) weak var button: NSStatusBarButton?

    private let item: NSStatusItem

    init() {
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.target = self
        item.button?.action = #selector(clicked)
        Self.button = item.button
        showUnavailable()
    }

    func remove() {
        NSStatusBar.system.removeStatusItem(item)
        Self.button = nil
    }

    @objc private func clicked() { togglePanel() }

    func update(session: LimitWindow?, week: LimitWindow?) {
        let title = NSMutableAttributedString()
        segment("S", window: session, kind: .session, into: title)
        title.append(NSAttributedString(string: "  "))
        segment("W", window: week, kind: .weekly, into: title)
        item.button?.attributedTitle = title
    }

    func showUnavailable() { update(session: nil, week: nil) }

    private func segment(
        _ label: String, window: LimitWindow?, kind: LimitWindowKind,
        into out: NSMutableAttributedString
    ) {
        out.append(NSAttributedString(string: label + " ", attributes: [
            .font: NSFont.systemFont(ofSize: 9, weight: .bold),
            .foregroundColor: fixedColor ?? NSColor.secondaryLabelColor,
            .baselineOffset: 1.5,
        ]))
        let numberFont = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .semibold)
        guard let window else {
            out.append(NSAttributedString(string: "\u{2013}", attributes: [
                .font: numberFont, .foregroundColor: fixedColor ?? NSColor.tertiaryLabelColor,
            ]))
            return
        }
        out.append(NSAttributedString(string: "\(Int(window.percent.rounded()))", attributes: [
            .font: numberFont, .foregroundColor: fixedColor ?? color(for: window, kind: kind),
        ]))
    }

    // MARK: - Color

    private func color(for window: LimitWindow, kind: LimitWindowKind) -> NSColor {
        let d = UserDefaults.standard
        if d.object(forKey: "smartColor") as? Bool ?? true {
            let risk = LimitMath.smartRisk(
                utilization: window.percent, resetsAt: window.resetsAt,
                windowDuration: kind.duration,
                pacingMargin: d.object(forKey: "pacingMargin") as? Double ?? 10)
            return Self.color(forRisk: risk)
        }
        switch UsageLevel.from(pct: window.percent, thresholds: .fromDefaults(d)) {
        case .green: return .systemGreen
        case .orange: return .systemOrange
        case .red: return .systemRed
        }
    }

    /// "white" / "black" -> that color for every part of the widget;
    /// "auto" (default) -> gray labels + risk-tinted numbers.
    private var fixedColor: NSColor? {
        switch UserDefaults.standard.string(forKey: "menuBarColorMode") {
        case "white": return .white
        case "black": return .black
        default: return nil
        }
    }

    /// Continuous risk color, TokenEater's 4-stop gradient: green until 0.30,
    /// green->orange to 0.55, orange->red to 0.85, red beyond. HSB-space
    /// interpolation keeps the midpoints vivid instead of muddy sRGB olives.
    static func color(forRisk risk: Double) -> NSColor {
        let r = max(0, min(1, risk))
        let green = NSColor.systemGreen, orange = NSColor.systemOrange, red = NSColor.systemRed
        if r <= 0.30 { return green }
        if r >= 0.85 { return red }
        if r <= 0.55 { return interpolateHSB(green, orange, t: (r - 0.30) / 0.25) }
        return interpolateHSB(orange, red, t: (r - 0.55) / 0.30)
    }

    private static func interpolateHSB(_ a: NSColor, _ b: NSColor, t: Double) -> NSColor {
        let f = CGFloat(max(0, min(1, t)))
        guard let x = a.usingColorSpace(.sRGB), let y = b.usingColorSpace(.sRGB) else { return a }
        let dh = y.hueComponent - x.hueComponent
        // short-path hue interpolation around the wheel
        let h: CGFloat
        if abs(dh) <= 0.5 { h = (x.hueComponent + dh * f + 1).truncatingRemainder(dividingBy: 1) }
        else if dh > 0.5 { h = (x.hueComponent + (dh - 1) * f + 1).truncatingRemainder(dividingBy: 1) }
        else { h = (x.hueComponent + (dh + 1) * f + 1).truncatingRemainder(dividingBy: 1) }
        return NSColor(
            hue: h,
            saturation: x.saturationComponent + (y.saturationComponent - x.saturationComponent) * f,
            brightness: x.brightnessComponent + (y.brightnessComponent - x.brightnessComponent) * f,
            alpha: 1)
    }
}
