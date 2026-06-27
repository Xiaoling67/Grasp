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

    // — Additional tokens for commonly-used colors —
    static let fillTertiary      = Color(hex: "F8F8F8")   // light content background
    static let accentGreen       = Color(hex: "15803D")   // success / saved text
    static let accentRed         = Color(hex: "B91C1C")   // error / stop
    static let accentAmber       = Color(hex: "F59E0B")   // warning
    static let pillBorderGray    = Color(hex: "E8E8E8")   // 1px border close to divider
    static let mutedGray         = Color(hex: "C0C0C0")   // secondary icon/text
    static let nearBlack         = Color(hex: "0A0A0A")   // near-black text
    static let mediumGray        = Color(hex: "5A5A5A")   // medium gray text
    static let lightBlueBg       = Color(hex: "E8F0FE")   // selected tab background
    static let lightBlueBorder   = Color(hex: "C5D8FC")   // selected tab border
    static let lightGreenBg      = Color(hex: "F0FDF4")   // green badge bg
    static let knowledgeBlue     = Color(hex: "3B67D6")   // knowledge badge text
    static let linkBlue          = Color(hex: "3B7DD8")   // user note link text
    static let highlightBlue     = Color(hex: "4A8BFA")   // gradient highlight
    static let veryLightGray     = Color(hex: "D0D0D0")   // empty state text
    static let statusGreen       = Color(hex: "34C759")   // status badge green
    static let statusBlue        = Color(hex: "007AFF")   // status badge blue
    static let statusGray        = Color(hex: "8E8E93")   // status badge gray
    static let statusOrange      = Color(hex: "FF9500")   // status badge orange
    static let amberBorder       = Color(hex: "FBBF24")   // amber border
    static let lightPurpleBg     = Color(hex: "EDE9FE")   // purple card bg
    static let searchCountGray   = Color(hex: "999999")   // search count text
    static let badgeBgGray       = Color(hex: "F0F0F0")   // badge background
    static let stopBorderRed     = Color(hex: "DC3545")   // stop button border
    static let notesDividerGray  = Color(hex: "AAAAAA")   // notes divider
    static let deepBlue          = Color(hex: "3B7DD8")   // user note text
    static let pillBorderColor   = Color(hex: "E8E8E8")   // tab/border pill
}
