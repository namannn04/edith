import EdithKit
import SwiftUI

enum InstallerSkin {
    static func paper(_ dark: Bool) -> Color {
        dark
            ? Color(.sRGB, red: 26 / 255, green: 23 / 255, blue: 20 / 255)
            : Color(.sRGB, red: 247 / 255, green: 243 / 255, blue: 236 / 255)
    }

    static func paperRaised(_ dark: Bool) -> Color {
        dark
            ? Color(.sRGB, red: 34 / 255, green: 29 / 255, blue: 25 / 255)
            : Color(.sRGB, red: 1, green: 253 / 255, blue: 248 / 255)
    }

    static func ink(_ dark: Bool) -> Color {
        dark
            ? Color(.sRGB, red: 241 / 255, green: 233 / 255, blue: 220 / 255)
            : Color(.sRGB, red: 36 / 255, green: 31 / 255, blue: 26 / 255)
    }

    static func inkSoft(_ dark: Bool) -> Color {
        dark
            ? Color(.sRGB, red: 188 / 255, green: 174 / 255, blue: 156 / 255)
            : Color(.sRGB, red: 92 / 255, green: 82 / 255, blue: 71 / 255)
    }

    static func inkFaint(_ dark: Bool) -> Color {
        dark
            ? Color(.sRGB, red: 138 / 255, green: 125 / 255, blue: 108 / 255)
            : Color(.sRGB, red: 138 / 255, green: 127 / 255, blue: 114 / 255)
    }

    static func line(_ dark: Bool) -> Color {
        dark
            ? Color(.sRGB, red: 51 / 255, green: 46 / 255, blue: 39 / 255)
            : Color(.sRGB, red: 228 / 255, green: 220 / 255, blue: 207 / 255)
    }

    static func lineStrong(_ dark: Bool) -> Color {
        dark
            ? Color(.sRGB, red: 66 / 255, green: 59 / 255, blue: 50 / 255)
            : Color(.sRGB, red: 214 / 255, green: 203 / 255, blue: 184 / 255)
    }

    static let danger = Color(.sRGB, red: 1, green: 59 / 255, blue: 48 / 255)

    static func serif(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .custom("Iowan Old Style", size: size).weight(weight)
    }

    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}
