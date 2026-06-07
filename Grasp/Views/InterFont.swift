import SwiftUI
import CoreText

enum Inter {
    static func registerAll() {
        guard let url = Bundle.main.url(forResource: "Inter", withExtension: "ttc", subdirectory: "Resources") else { return }
        CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
    }
}

extension Font {
    static func inter(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom(name(weight), size: size)
    }

    private static func name(_ w: Font.Weight) -> String {
        switch w {
        case .light:    return "Inter-Light"
        case .medium:   return "Inter-Medium"
        case .semibold: return "Inter-SemiBold"
        case .bold:     return "Inter-Bold"
        default:        return "Inter-Regular"
        }
    }
}
