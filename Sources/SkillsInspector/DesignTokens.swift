import SwiftUI
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

/// Shared design tokens ported from aStudio (Jan 2026 snapshot).
/// Keep this file generated-only to ensure parity across views.
public enum DesignTokens {
    public enum Colors {
        public enum Background {
            public static let lightPrimary = Color(hex: "#FFFFFF")
            public static let lightSecondary = Color(hex: "#E8E8E8")
            public static let lightTertiary = Color(hex: "#F3F3F3")
            public static let darkPrimary = Color(hex: "#212121")
            public static let darkSecondary = Color(hex: "#303030")
            public static let darkTertiary = Color(hex: "#414141")
            public static let primary = Color.dynamicColor(lightHex: "#FFFFFF", darkHex: "#212121")
            public static let secondary = Color.dynamicColor(lightHex: "#E8E8E8", darkHex: "#303030")
            public static let tertiary = Color.dynamicColor(lightHex: "#F3F3F3", darkHex: "#414141")
        }

        public enum Text {
            public static let primary = Color.dynamicColor(lightHex: "#0D0D0D", darkHex: "#FFFFFF")
            public static let secondary = Color.dynamicColor(lightHex: "#5D5D5D", darkHex: "#CDCDCD")
            public static let tertiary = Color.dynamicColor(lightHex: "#8F8F8F", darkHex: "#AFAFAF")
            public static let inverted = Color.dynamicColor(lightHex: "#FFFFFF", darkHex: "#0D0D0D")
        }

        public enum Icon {
            public static let primary = Color.dynamicColor(lightHex: "#0D0D0D", darkHex: "#FFFFFF")
            public static let secondary = Color.dynamicColor(lightHex: "#5D5D5D", darkHex: "#CDCDCD")
            public static let tertiary = Color.dynamicColor(lightHex: "#8F8F8F", darkHex: "#AFAFAF")
            public static let inverted = Color.dynamicColor(lightHex: "#FFFFFF", darkHex: "#0D0D0D")
            public static let accent = Color.dynamicColor(lightHex: "#0285FF", darkHex: "#48AAFF")
            public static let statusError = Color.dynamicColor(lightHex: "#E02E2A", darkHex: "#FF8583")
            public static let statusWarning = Color.dynamicColor(lightHex: "#E25507", darkHex: "#FF9E6C")
            public static let statusSuccess = Color.dynamicColor(lightHex: "#008635", darkHex: "#40C977")
        }

        public enum Border {
            public static let light = Color.dynamicColor(lightHex: "#0D0D0D0D", darkHex: "#FFFFFF0D")
            public static let heavy = Color.dynamicColor(lightHex: "#0D0D0D26", darkHex: "#FFFFFF26")
        }

        public enum Accent {
            public static let gray = Color.dynamicColor(lightHex: "#8F8F8F", darkHex: "#ABABAB")
            public static let red = Color.dynamicColor(lightHex: "#E02E2A", darkHex: "#FF8583")
            public static let orange = Color.dynamicColor(lightHex: "#E25507", darkHex: "#FF9E6C")
            public static let yellow = Color.dynamicColor(lightHex: "#C08C00", darkHex: "#FFD666")
            public static let green = Color.dynamicColor(lightHex: "#008635", darkHex: "#40C977")
            public static let blue = Color.dynamicColor(lightHex: "#0285FF", darkHex: "#5A9FF5")
            public static let purple = Color.dynamicColor(lightHex: "#934FF2", darkHex: "#BA8FF7")
            public static let pink = Color.dynamicColor(lightHex: "#E3008D", darkHex: "#FF6BC7")
        }
        
        public enum Status {
            public static let success = Accent.green
            public static let warning = Accent.orange
            public static let error = Accent.red
            public static let info = Accent.blue
        }
    }

    public enum Typography {
        public static let fontFamily = "SF Pro"
        public enum Heading1 { public static let size: CGFloat = 36; public static let line: CGFloat = 40; public static let weight = Font.Weight.semibold; public static let tracking: CGFloat = -0.1 }
        public enum Heading2 { public static let size: CGFloat = 24; public static let line: CGFloat = 28; public static let weight = Font.Weight.semibold; public static let tracking: CGFloat = -0.25 }
        public enum Heading3 { public static let size: CGFloat = 18; public static let line: CGFloat = 26; public static let weight = Font.Weight.semibold; public static let tracking: CGFloat = -0.45 }
        public enum Body { public static let size: CGFloat = 16; public static let line: CGFloat = 26; public static let weight = Font.Weight.regular; public static let emphasis = Font.Weight.semibold; public static let tracking: CGFloat = -0.4 }
        public enum BodySmall { public static let size: CGFloat = 14; public static let line: CGFloat = 18; public static let weight = Font.Weight.regular; public static let emphasis = Font.Weight.semibold; public static let tracking: CGFloat = -0.3 }
        public enum Caption { public static let size: CGFloat = 12; public static let line: CGFloat = 16; public static let weight = Font.Weight.regular; public static let emphasis = Font.Weight.semibold; public static let tracking: CGFloat = -0.1 }
    }

    public enum Spacing {
        public static let xxxl: CGFloat = 128
        public static let xxl: CGFloat = 64
        public static let xl: CGFloat = 48
        public static let lg: CGFloat = 40
        public static let md: CGFloat = 32
        public static let sm: CGFloat = 24
        public static let xs: CGFloat = 16
        public static let xxs: CGFloat = 12
        public static let xxxs: CGFloat = 8
        public static let hair: CGFloat = 4
        public static let micro: CGFloat = 2
        public static let none: CGFloat = 0
    }

    public enum Radius {
        public static let sm: CGFloat = 6
        public static let md: CGFloat = 8
        public static let lg: CGFloat = 12
        public static let xl: CGFloat = 16
        public static let pill: CGFloat = 999
    }

    public enum Shadow {
        public static let card = ShadowSpec(radius: 16, x: 0, y: 4, color: Color.black.opacity(0.05))
        public static let subtle = ShadowSpec(radius: 8, x: 0, y: 2, color: Color.black.opacity(0.03))
        public static let elevated = ShadowSpec(radius: 24, x: 0, y: 8, color: Color.black.opacity(0.08))
    }
    
    public enum Layout {
        public static let sidebarMinWidth: CGFloat = 220
        public static let sidebarIdealWidth: CGFloat = 260
        public static let sidebarMaxWidth: CGFloat = 340
        public static let minRowHeight: CGFloat = 36
    }
        public static let pip = ShadowSpec(radius: 16, x: 0, y: 4, color: Color.black.opacity(0.05))
        public static let pill = ShadowSpec(radius: 22, x: 0, y: 10, color: Color.black.opacity(0.04))
        public static let close = ShadowSpec(radius: 8, x: 0, y: 4, color: Color.black.opacity(0.16))
    }

    public struct ShadowSpec {
        public let radius: CGFloat
        public let x: CGFloat
        public let y: CGFloat
        public let color: Color
    }
}

// MARK: - Helpers copied from aStudio token runtime

private extension Color {
    init(hex: String) {
        let scanner = Scanner(string: hex.trimmingCharacters(in: CharacterSet(charactersIn: "#")))
        var hexNumber: UInt64 = 0
        scanner.scanHexInt64(&hexNumber)
        let r = Double((hexNumber & 0xFF0000) >> 16) / 255
        let g = Double((hexNumber & 0x00FF00) >> 8) / 255
        let b = Double(hexNumber & 0x0000FF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: 1)
    }

    static func dynamicColor(lightHex: String, darkHex: String) -> Color {
        #if canImport(UIKit)
        return Color(UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(hex: darkHex) : UIColor(hex: lightHex)
        })
        #else
        return Color(NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? NSColor(hex: darkHex) : NSColor(hex: lightHex)
        })
        #endif
    }
}

#if canImport(UIKit)
private extension UIColor {
    convenience init(hex: String) {
        var hexString = hex
        if hexString.hasPrefix("#") { hexString.removeFirst() }
        var hexNumber: UInt64 = 0
        Scanner(string: hexString).scanHexInt64(&hexNumber)
        let r = CGFloat((hexNumber & 0xFF0000) >> 16) / 255
        let g = CGFloat((hexNumber & 0x00FF00) >> 8) / 255
        let b = CGFloat(hexNumber & 0x0000FF) / 255
        self.init(red: r, green: g, blue: b, alpha: 1)
    }
}
#else
private extension NSColor {
    convenience init(hex: String) {
        var hexString = hex
        if hexString.hasPrefix("#") { hexString.removeFirst() }
        var hexNumber: UInt64 = 0
        Scanner(string: hexString).scanHexInt64(&hexNumber)
        let r = CGFloat((hexNumber & 0xFF0000) >> 16) / 255
        let g = CGFloat((hexNumber & 0x00FF00) >> 8) / 255
        let b = CGFloat(hexNumber & 0x0000FF) / 255
        self.init(red: r, green: g, blue: b, alpha: 1)
    }
}
#endif

// MARK: - Typography View Extensions

public extension View {
    func heading1() -> some View {
        self.font(.system(size: DesignTokens.Typography.Heading1.size,
                         weight: DesignTokens.Typography.Heading1.weight))
            .tracking(DesignTokens.Typography.Heading1.tracking)
    }
    
    func heading2() -> some View {
        self.font(.system(size: DesignTokens.Typography.Heading2.size,
                         weight: DesignTokens.Typography.Heading2.weight))
            .tracking(DesignTokens.Typography.Heading2.tracking)
    }
    
    func heading3() -> some View {
        self.font(.system(size: DesignTokens.Typography.Heading3.size,
                         weight: DesignTokens.Typography.Heading3.weight))
            .tracking(DesignTokens.Typography.Heading3.tracking)
    }
    
    func bodyText(emphasis: Bool = false) -> some View {
        self.font(.system(size: DesignTokens.Typography.Body.size,
                         weight: emphasis ? DesignTokens.Typography.Body.emphasis : DesignTokens.Typography.Body.weight))
            .tracking(DesignTokens.Typography.Body.tracking)
    }
    
    func bodySmall(emphasis: Bool = false) -> some View {
        self.font(.system(size: DesignTokens.Typography.BodySmall.size,
                         weight: emphasis ? DesignTokens.Typography.BodySmall.emphasis : DesignTokens.Typography.BodySmall.weight))
            .tracking(DesignTokens.Typography.BodySmall.tracking)
    }
    
    func captionText(emphasis: Bool = false) -> some View {
        self.font(.system(size: DesignTokens.Typography.Caption.size,
                         weight: emphasis ? DesignTokens.Typography.Caption.emphasis : DesignTokens.Typography.Caption.weight))
            .tracking(DesignTokens.Typography.Caption.tracking)
    }
}

