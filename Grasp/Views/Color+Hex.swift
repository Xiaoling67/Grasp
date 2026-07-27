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

// MARK: - Design Tokens — v1.1-r3
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
    static let body:      CGFloat = 14
    static let caption:   CGFloat = 11
    static let small:     CGFloat = 10
    static let title:     CGFloat = 16
    static let lineHeight: CGFloat = 1.45
}

// ── Semantic Colors ──
// Grasp UI blue system:
// Primary blue: #2384E8. Page/background fills stay pure white (#FFFFFF).
extension Color {
    static let appBackground     = Color(hex: "FFFFFF")
    static let pastelBlue        = Color(hex: "FFFFFF")
    static let pastelBlueStrong  = Color(hex: "FFFFFF")
    static let pastelGreen       = Color(hex: "FFFFFF")
    static let pastelGreenBorder = Color(hex: "9CCBF4")
    static let pastelYellow      = Color(hex: "FFF4CC")
    static let pastelYellowBorder = Color(hex: "E8C85C")
    static let pastelPink        = Color(hex: "FFE8EF")
    static let pastelPinkBorder  = Color(hex: "F3C0CF")
    static let pastelLilac       = Color(hex: "F1EAFE")
    static let warmCream         = Color(hex: "FFFFFF")

    static let surfacePrimary    = Color(hex: "FFFFFF")
    static let surfaceSecondary  = Color(hex: "FFFFFF")
    static let textPrimary       = Color(hex: "202124")
    static let textSecondary     = Color(hex: "626B78")
    static let textTertiary      = Color(hex: "98A1AD")
    static let accentBlue        = Color(hex: "2384E8")
    static let accentPurple      = Color(hex: "B57BE8")
    static let divider           = Color(hex: "2384E8").opacity(0.55)  // stronger accent divider between panels
    static let selectionBg       = Color(hex: "FFFFFF")
    static let hoverBg           = Color(hex: "FFFFFF")
    static let aiNewBorder       = Color(hex: "2384E8")

    // — Additional tokens for commonly-used colors —
    static let fillTertiary      = Color(hex: "FFFFFF")   // light content background
    static let accentGreen       = Color(hex: "2384E8")   // success / saved text
    static let accentRed         = Color(hex: "D85B66")   // error / stop
    static let accentAmber       = Color(hex: "2384E8")   // legacy warning, mapped to primary blue in live UI
    static let pillBorderGray    = Color(hex: "C7DBEE")   // 1px border close to divider
    static let mutedGray         = Color(hex: "B7C0CB")   // secondary icon/text
    static let nearBlack         = Color(hex: "17191C")   // near-black text
    static let mediumGray        = Color(hex: "5D6876")   // medium gray text
    static let lightBlueBg       = Color(hex: "FFFFFF")   // selected tab background
    static let lightBlueBorder   = Color(hex: "9CCBF4")   // selected tab border
    static let lightGreenBg      = Color(hex: "FFFFFF")   // saved badge bg
    static let knowledgeBlue     = Color(hex: "2384E8")   // knowledge badge text
    static let linkBlue          = Color(hex: "2384E8")   // user note link text
    static let highlightBlue     = Color(hex: "6EB6FF")   // gradient highlight
    static let veryLightGray     = Color(hex: "CBD4DE")   // empty state text
    static let statusGreen       = Color(hex: "2384E8")   // status badge blue
    static let statusBlue        = Color(hex: "2384E8")   // status badge blue
    static let statusGray        = Color(hex: "8E8E93")   // status badge gray
    static let statusOrange      = Color(hex: "F0A62B")   // status badge orange
    static let amberBorder       = Color(hex: "CFEAFF")   // legacy warning border, mapped to primary blue in live UI
    static let lightPurpleBg     = Color(hex: "FFFFFF")   // purple card bg
    static let searchCountGray   = Color(hex: "9BA5B1")   // search count text
    static let badgeBgGray       = Color(hex: "FFFFFF")   // badge background
    static let stopBorderRed     = Color(hex: "F2B5BC")   // stop button border
    static let notesDividerGray  = Color(hex: "9CCBF4")   // notes divider
    static let deepBlue          = Color(hex: "2384E8")   // user note text
    static let pillBorderColor   = Color(hex: "C7DBEE")   // tab/border pill
}
