import SwiftUI

// SF Pro is the iOS system font. Match the prototype's tight tracking on display sizes.
extension Font {
    static let zHero       = Font.system(size: 48, weight: .semibold, design: .default)
    static let zDisplay    = Font.system(size: 28, weight: .semibold, design: .default)
    static let zTitle      = Font.system(size: 22, weight: .semibold, design: .default)
    static let zSubtitle   = Font.system(size: 18, weight: .semibold, design: .default)
    static let zBody       = Font.system(size: 17, weight: .regular,  design: .default)
    static let zBodyBold   = Font.system(size: 17, weight: .semibold, design: .default)
    static let zCaption    = Font.system(size: 13, weight: .regular,  design: .default)
    static let zCaptionBold = Font.system(size: 13, weight: .semibold, design: .default)
    static let zEyebrow    = Font.system(size: 11, weight: .semibold, design: .default)
    static let zMicro      = Font.system(size: 10, weight: .semibold, design: .default)
    // Big numeric for distance hero
    static func zBigNumber(_ size: CGFloat) -> Font {
        .system(size: size, weight: .semibold, design: .default)
    }
}

extension Text {
    /// Apple-tight letter spacing on display sizes (negative tracking).
    func zTight() -> Text { self.tracking(-0.5) }
}
