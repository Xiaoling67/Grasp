import SwiftUI

// MARK: - Color Hex Initializer
extension Color {
    init(hex: String) {
        let h = hex.trimmingCharacters(in: .alphanumerics.inverted)
        var i: UInt64 = 0
        Scanner(string: h).scanHexInt64(&i)
        self.init(red: Double((i>>16)&0xFF)/255, green: Double((i>>8)&0xFF)/255, blue: Double(i&0xFF)/255)
    }
}

// MARK: - Design Tokens — v1.1-r2
// Centralized design system per PRD §4.
// Never hardcode hex colors, arbitrary padding, or ad-hoc font sizes.

// ── Spacing (4px grid) ──
enum Spacing {
    static let xxxs: CGFloat = 2
    static let xxs:  CGFloat = 4
    static let xs:   CGFloat = 8
    static let sm:   CGFloat = 12
    static let md:   CGFloat = 16
    static let lg:   CGFloat = 24
    static let xl:   CGFloat = 32
    static let xxl:  CGFloat = 48
}

// ── Corner Radii ──
enum CornerRadius {
    static let card:   CGFloat = 8
    static let popup:  CGFloat = 12
    static let pill:   CGFloat = 980  // fully rounded
}

// ── Typography ──
enum AppTypography {
    static let body:      CGFloat = 13
    static let caption:   CGFloat = 11
    static let small:     CGFloat = 10
    static let title:     CGFloat = 14
    static let lineHeight: CGFloat = 1.4
}

// ── Semantic Colors ──
extension Color {
    static let surfacePrimary    = Color(hex: "FFFFFF")
    static let surfaceSecondary  = Color(hex: "F5F5F5")
    static let textPrimary       = Color(hex: "1A1A1A")
    static let textSecondary     = Color(hex: "6B6B6B")
    static let textTertiary      = Color(hex: "9E9E9E")
    static let accentBlue        = Color(hex: "2563EB")
    static let accentPurple      = Color(hex: "7C3AED")
    static let divider           = Color(hex: "E5E5E5")
    static let selectionBg       = Color(hex: "DBEAFE")
    static let hoverBg           = Color(hex: "F5F5F5")
    static let aiNewBorder       = Color(hex: "1A5FD4")
}
