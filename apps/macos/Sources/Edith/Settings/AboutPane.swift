import AppKit
import EdithKit
import SwiftUI

struct AboutPane: View {
    @AppStorage("theme", store: SharedDefaults.store) private var themeName = "accent"

    private var theme: Color { themeColor(themeName) }

    private var version: String {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "-"
        return "Version \(short)"
    }

    private let story = """
        Hi, I'm Pulkit, the builder of Edith. I used to pay for a whole shelf of \
        separate Mac apps: one to watch usage, one for the menu bar, one for music, \
        and on it went. It never sat right with me. So I set out to build a single \
        app that brings all of those little features under one roof. That's Edith.
        """

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    Spacer(minLength: 44)
                    content
                    Spacer(minLength: 44)
                }
                .frame(maxWidth: .infinity, minHeight: proxy.size.height)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .navigationTitle("About")
    }

    private var content: some View {
        VStack(spacing: 18) {
            if let icon = Brand.icon {
                Image(nsImage: icon)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 88, height: 88)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .shadow(color: .black.opacity(0.25), radius: 12, y: 6)
            }
            VStack(spacing: 6) {
                Text("Edith")
                    .font(.system(size: 28, weight: .bold))
                Text(version)
                    .font(.system(size: 12))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Text("Every little Mac utility you'd otherwise pay for, under one roof.")
                .font(.system(size: 14, weight: .medium))
                .multilineTextAlignment(.center)
            Text(story)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .frame(maxWidth: 460)
            Button {
                NSWorkspace.shared.open(URL(string: "https://pulkit.page")!)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "link")
                        .font(.system(size: 11, weight: .semibold))
                    Text("pulkit.page")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(theme, in: Capsule())
            }
            .buttonStyle(.plain)
            .pointerCursor()
            .padding(.top, 2)
            Text("Made with ♥ by Pulkit")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 32)
    }
}
