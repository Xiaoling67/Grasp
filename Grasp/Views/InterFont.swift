import SwiftUI
import AppKit
import CoreText

enum Inter {
    static func registerAll() {
        guard let url = Bundle.main.url(forResource: "Inter", withExtension: "ttc") else { return }
        CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
    }
}

extension Font {
    static func inter(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    private static func name(_ w: Font.Weight) -> String {
        switch w {
        case .light:    return "Inter-Light"
        case .regular:  return "Inter-Regular"
        case .medium:   return "Inter-Medium"
        case .semibold: return "Inter-SemiBold"
        case .bold:     return "Inter-Bold"
        default:        return "Inter-Regular"
        }
    }
}

extension NSFont {
    static func graspRounded(size: CGFloat, weight: NSFont.Weight = .regular) -> NSFont {
        let base = NSFont.systemFont(ofSize: size, weight: weight)
        guard let descriptor = base.fontDescriptor.withDesign(.rounded),
              let rounded = NSFont(descriptor: descriptor, size: size) else {
            return base
        }
        return rounded
    }
}
