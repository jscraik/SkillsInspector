import SwiftUI
import AStudioFoundation
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
            public static let tertiary = Color.dynamicColor(lightHex: "#8F8F8F", darkHex: "#D0D0D0")
            public static let inverted = Color.dynamicColor(lightHex: "#FFFFFF", darkHex: "#0D0D0D")
        }

        public enum Icon {
            public static let primary = Color.dynamicColor(lightHex: "#0D0D0D", darkHex: "#FFFFFF")
            public static let secondary = Color.dynamicColor(lightHex: "#5D5D5D", darkHex: "#CDCDCD")
            public static let tertiary = Color.dynamicColor(lightHex: "#8F8F8F", darkHex: "#D0D0D0")
            public static let inverted = Color.dynamicColor(lightHex: "#FFFFFF", darkHex: "#0D0D0D")
            public static let accent = Color.dynamicColor(lightHex: "#0285FF", darkHex: "#48AAFF")
            public static let statusError = Color.dynamicColor(lightHex: "#E02E2A", darkHex: "#FF8583")
            public static let statusWarning = Color.dynamicColor(lightHex: "#E25507", darkHex: "#FF9E6C")
            public static let statusSuccess = Color.dynamicColor(lightHex: "#008635", darkHex: "#40C977")
        }

        public enum Border {
            public static let light = Color.dynamicColor(lightHex: "#0D0D0D0D", darkHex: "#FFFFFF0D")
            public static let heavy = Color.dynamicColor(lightHex: "#0D0D0D26", darkHex: "#FFFFFF26")
            public static let accent = Color.dynamicColor(lightHex: "#0285FF33", darkHex: "#48AAFF33")
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
        public enum Caption { public static let size: CGFloat = 11; public static let line: CGFloat = 16; public static let weight = Font.Weight.regular; public static let emphasis = Font.Weight.semibold; public static let tracking: CGFloat = -0.1 }
        public enum Subcaption { public static let size: CGFloat = 10; public static let line: CGFloat = 14; public static let weight = Font.Weight.regular; public static let emphasis = Font.Weight.semibold; public static let tracking: CGFloat = 0 }
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

    // MARK: - Corner Radius

    public enum CornerRadius {
        public static let small: CGFloat = 6
        public static let medium: CGFloat = 8
        public static let large: CGFloat = 12
        public static let extraLarge: CGFloat = 16
    }

    public enum Shadow {
        public static let card = ShadowSpec(radius: 16, x: 0, y: 4, color: Color.black.opacity(0.05))
        public static let subtle = ShadowSpec(radius: 8, x: 0, y: 2, color: Color.black.opacity(0.03))
        public static let elevated = ShadowSpec(radius: 24, x: 0, y: 8, color: Color.black.opacity(0.08))
        public static let pip = ShadowSpec(radius: 16, x: 0, y: 4, color: Color.black.opacity(0.05))
        public static let pill = ShadowSpec(radius: 22, x: 0, y: 10, color: Color.black.opacity(0.04))
        public static let close = ShadowSpec(radius: 8, x: 0, y: 4, color: Color.black.opacity(0.16))
    }
    
    public enum Layout {
        public static let sidebarMinWidth: CGFloat = 220
        public static let sidebarIdealWidth: CGFloat = 260
        public static let sidebarMaxWidth: CGFloat = 340
        public static let minRowHeight: CGFloat = 36
        public static let sectionSpacing: CGFloat = 20
        public static let cardSpacing: CGFloat = 12
    }

    public struct ShadowSpec {
        public let radius: CGFloat
        public let x: CGFloat
        public let y: CGFloat
        public let color: Color
    }
}

// MARK: - aStudio Bridge Extensions

/// Bridge extensions to provide gradual migration path from DesignTokens to aStudio tokens
/// This allows using either API during migration while maintaining backward compatibility
/// Usage:
///   Text("Hello").foregroundColor(DesignTokens.Colors.Text.fPrimary)
public extension DesignTokens.Colors.Text {
    /// Bridge to aStudio FColor.textPrimary
    public static var fTextPrimary: Color {
        #if canImport(AStudioFoundation)
        import AStudioFoundation
        return FColor.textPrimary
        #else
        return DesignTokens.Colors.Text.primary
        #endif
    }

    /// Bridge to aStudio FColor.textSecondary
    public static var fTextSecondary: Color {
        #if canImport(AStudioFoundation)
        import AStudioFoundation
        return FColor.textSecondary
        #else
        return DesignTokens.Colors.Text.secondary
        #endif
    }

    /// Bridge to aStudio FColor.textTertiary
    public static var fTextTertiary: Color {
        #if canImport(AStudioFoundation)
        import AStudioFoundation
        return FColor.textTertiary
        #else
        return DesignTokens.Colors.Text.tertiary
        #endif
    }
}

public extension DesignTokens.Colors.Icon {
    /// Bridge to aStudio FColor.iconPrimary
    public static var fIconPrimary: Color {
        #if canImport(AStudioFoundation)
        import AStudioFoundation
        return FColor.iconPrimary
        #else
        return DesignTokens.Colors.Icon.primary
        #endif
    }

    /// Bridge to aStudio FColor.iconSecondary
    public static var fIconSecondary: Color {
        #if canImport(AStudioFoundation)
        import AStudioFoundation
        return FColor.iconSecondary
        #else
        return DesignTokens.Colors.Icon.secondary
        #endif
    }

    /// Bridge to aStudio FColor.iconTertiary
    public static var fIconTertiary: Color {
        #if canImport(AStudioFoundation)
        import AStudioFoundation
        return FColor.iconTertiary
        #else
        return DesignTokens.Colors.Icon.tertiary
        #endif
    }
}

public extension DesignTokens.Colors.Accent {
    /// Bridge to aStudio FColor.accentBlue
    public static var fAccentBlue: Color {
        #if canImport(AStudioFoundation)
        import AStudioFoundation
        return FColor.accentBlue
        #else
        return DesignTokens.Colors.Accent.blue
        #endif
    }

    /// Bridge to aStudio FColor.accentGreen
    public static var fAccentGreen: Color {
        #if canImport(AStudioFoundation)
        import AStudioFoundation
        return FColor.accentGreen
        #else
        return DesignTokens.Colors.Accent.green
        #endif
    }

    /// Bridge to aStudio FColor.accentRed
    public static var fAccentRed: Color {
        #if canImport(AStudioFoundation)
        import AStudioFoundation
        return FColor.accentRed
        #else
        return DesignTokens.Colors.Accent.red
        #endif
    }

    /// Bridge to aStudio FColor.accentOrange
    public static var fAccentOrange: Color {
        #if canImport(AStudioFoundation)
        import AStudioFoundation
        return FColor.accentOrange
        #else
        return DesignTokens.Colors.Accent.orange
        #endif
    }

    /// Bridge to aStudio FColor.accentPurple
    public static var fAccentPurple: Color {
        #if canImport(AStudioFoundation)
        import AStudioFoundation
        return FColor.accentPurple
        #else
        return DesignTokens.Colors.Accent.purple
        #endif
    }
}

public extension DesignTokens.Colors.Status {
    /// Bridge to aStudio FColor.accentGreen
    public static var fStatusSuccess: Color {
        #if canImport(AStudioFoundation)
        import AStudioFoundation
        return FColor.accentGreen
        #else
        return DesignTokens.Colors.Status.success
        #endif
    }

    /// Bridge to aStudio FColor.accentRed
    public static var fStatusError: Color {
        #if canImport(AStudioFoundation)
        import AStudioFoundation
        return FColor.accentRed
        #else
        return DesignTokens.Colors.Status.error
        #endif
    }

    /// Bridge to aStudio FColor.accentOrange
    public static var fStatusWarning: Color {
        #if canImport(AStudioFoundation)
        import AStudioFoundation
        return FColor.accentOrange
        #else
        return DesignTokens.Colors.Status.warning
        #endif
    }
}

public extension DesignTokens.Spacing {
    /// Bridge to aStudio FSpacing.s16 (16pt)
    public static var fCard: CGFloat {
        #if canImport(AStudioFoundation)
        import AStudioFoundation
        return FSpacing.s16
        #else
        return DesignTokens.Spacing.xs
        #endif
    }

    /// Bridge to aStudio FSpacing.s12 (12pt)
    public static var fCompact: CGFloat {
        #if canImport(AStudioFoundation)
        import AStudioFoundation
        return FSpacing.s12
        #else
        return DesignTokens.Spacing.xxs
        #endif
    }

    /// Bridge to aStudio FSpacing.s24 (24pt)
    public static var fSection: CGFloat {
        #if canImport(AStudioFoundation)
        import AStudioFoundation
        return FSpacing.s24
        #else
        return DesignTokens.Spacing.sm
        #endif
    }
}

public extension DesignTokens.Typography {
    /// Bridge to aStudio FType.title (16pt semibold)
    public static var fTitle: Font {
        #if canImport(AStudioFoundation)
        import AStudioFoundation
        return FType.title()
        #else
        return Font.system(size: DesignTokens.Typography.Heading2.size, weight: DesignTokens.Typography.Heading2.weight)
        #endif
    }

    /// Bridge to aStudio FType.sectionTitle (13pt semibold)
    public static var fSection: Font {
        #if canImport(AStudioFoundation)
        import AStudioFoundation
        return FType.sectionTitle()
        #else
        return Font.system(size: DesignTokens.Typography.Heading3.size, weight: DesignTokens.Typography.Heading3.weight)
        #endif
    }

    /// Bridge to aStudio FType.rowTitle (14pt regular)
    public static var fRowTitle: Font {
        #if canImport(AStudioFoundation)
        import AStudioFoundation
        return FType.rowTitle()
        #else
        return Font.system(size: DesignTokens.Typography.Body.size, weight: DesignTokens.Typography.Body.weight)
        #endif
    }

    /// Bridge to aStudio FType.caption (12pt regular)
    public static var fCaption: Font {
        #if canImport(AStudioFoundation)
        import AStudioFoundation
        return FType.caption()
        #else
        return Font.system(size: DesignTokens.Typography.Caption.size, weight: DesignTokens.Typography.Caption.weight)
        #endif
    }
}

// MARK: - Helpers copied from aStudio token runtime

private extension Color {
    init(hex: String) {
        let hexString = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var hexNumber: UInt64 = 0
        Scanner(string: hexString).scanHexInt64(&hexNumber)
        
        let r, g, b, a: Double
        if hexString.count == 8 {
            r = Double((hexNumber & 0xFF000000) >> 24) / 255
            g = Double((hexNumber & 0x00FF0000) >> 16) / 255
            b = Double((hexNumber & 0x0000FF00) >> 8) / 255
            a = Double(hexNumber & 0x000000FF) / 255
        } else {
            r = Double((hexNumber & 0xFF0000) >> 16) / 255
            g = Double((hexNumber & 0x00FF00) >> 8) / 255
            b = Double(hexNumber & 0x0000FF) / 255
            a = 1.0
        }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
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
        let hexString = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var hexNumber: UInt64 = 0
        Scanner(string: hexString).scanHexInt64(&hexNumber)
        
        let r, g, b, a: CGFloat
        if hexString.count == 8 {
            r = CGFloat((hexNumber & 0xFF000000) >> 24) / 255
            g = CGFloat((hexNumber & 0x00FF0000) >> 16) / 255
            b = CGFloat((hexNumber & 0x0000FF00) >> 8) / 255
            a = CGFloat(hexNumber & 0x000000FF) / 255
        } else {
            r = CGFloat((hexNumber & 0xFF0000) >> 16) / 255
            g = CGFloat((hexNumber & 0x00FF00) >> 8) / 255
            b = CGFloat(hexNumber & 0x0000FF) / 255
            a = 1.0
        }
        self.init(red: r, green: g, blue: b, alpha: a)
    }
}
#else
private extension NSColor {
    convenience init(hex: String) {
        let hexString = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var hexNumber: UInt64 = 0
        Scanner(string: hexString).scanHexInt64(&hexNumber)
        
        let r, g, b, a: CGFloat
        if hexString.count == 8 {
            r = CGFloat((hexNumber & 0xFF000000) >> 24) / 255
            g = CGFloat((hexNumber & 0x00FF0000) >> 16) / 255
            b = CGFloat((hexNumber & 0x0000FF00) >> 8) / 255
            a = CGFloat(hexNumber & 0x000000FF) / 255
        } else {
            r = CGFloat((hexNumber & 0xFF0000) >> 16) / 255
            g = CGFloat((hexNumber & 0x00FF00) >> 8) / 255
            b = CGFloat(hexNumber & 0x0000FF) / 255
            a = 1.0
        }
        self.init(red: r, green: g, blue: b, alpha: a)
    }
}
#endif

