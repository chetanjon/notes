import SwiftUI

/// The whole design system: black, white, and four greys. The only accent
/// is white. Nothing here is ever red or blue.
enum Theme {
    static let bg = Color.black
    static let fg = Color.white
    /// Secondary text, timestamps.
    static let muted = Color(hex: 0x7A7A7A)
    /// Placeholders.
    static let faint = Color(hex: 0x444444)
    /// Search bar fill, pressed states.
    static let field = Color(hex: 0x1A1A1A)
    /// Row separators.
    static let rule = Color(hex: 0x222222)

    /// Horizontal page padding.
    static let pagePadding: CGFloat = 20
    /// Row vertical padding.
    static let rowPadding: CGFloat = 16
    /// Search bar height and corner radius.
    static let searchHeight: CGFloat = 44
    static let searchRadius: CGFloat = 12
    /// Compose button diameter.
    static let composeSize: CGFloat = 56
    /// Minimum tap target.
    static let tapTarget: CGFloat = 44

    /// Text styles, not point sizes, so every screen follows the size set
    /// in Settings > Display > Text Size. At the default size these are the
    /// spec's numbers: 34, 17, 15, 13.
    enum Font {
        /// Screen title: large title semibold, tracking -0.03em.
        static let screenTitle = SwiftUI.Font.system(.largeTitle, weight: .semibold)
        static let screenTitleTracking: CGFloat = -0.03 * 34
        /// Note title in a row.
        static let rowTitle = SwiftUI.Font.system(.body, weight: .semibold)
        /// Row preview and time.
        static let rowBody = SwiftUI.Font.system(.subheadline)
        /// Labels and meta.
        static let label = SwiftUI.Font.system(.footnote)
        /// The smallest line: the edit time under the editor's bar.
        static let meta = SwiftUI.Font.system(.caption)
        /// Toolbar text buttons.
        static let toolbar = SwiftUI.Font.system(.body, weight: .semibold)
        /// Glyph buttons in a bar.
        static let barGlyph = SwiftUI.Font.system(.title3)
        /// Editor body size and line height at the default text size, as
        /// the spec states them; the editor scales them with the body style.
        static let editorSize: CGFloat = 17
        static let editorLineHeight: CGFloat = 1.6
        /// The first line, drawn as a heading so it reads as the title.
        static let editorTitleSize: CGFloat = 22
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}
