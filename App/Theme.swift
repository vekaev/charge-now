import SwiftUI

/// The one place for how the overlay looks: white ink on a dimmed screen. Views use these, never a bare color,
/// gap or radius (scripts/check-design.sh fails the build otherwise).
enum Theme {
    /// The overlay is dark whatever the system appearance is: it is the screen, dimmed.
    static let shade = Color.black
    static let ink = Color.white
    /// Secondary text.
    static let quiet = Color.white.opacity(0.62)
    /// Hints at the bottom edge.
    static let faint = Color.white.opacity(0.4)
    static let line = Color.white.opacity(0.16)
    /// The only hue: the battery is nearly empty.
    static let danger = Color(red: 1.0, green: 0.42, blue: 0.38)

    /// How much of the screen's light the shade takes away, on top of the blur.
    static let dimWarning = 0.6
    static let dimBlock = 0.84

    /// A 4 pt grid. The same gap means the same thing everywhere.
    enum Space {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let s: CGFloat = 12
        static let m: CGFloat = 16
        static let l: CGFloat = 20
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
        /// From the hints to the bottom edge of the screen.
        static let edge: CGFloat = 64
    }

    enum Size {
        static let headline: CGFloat = 28
        static let detail: CGFloat = 15
        static let hint: CGFloat = 13
        /// The bar that fills while Esc is held.
        static let holdWidth: CGFloat = 132
        static let holdHeight: CGFloat = 2
    }

    /// The battery drawing above the headline, laid out on an 84 × 38 sketch: the charge that is left on the
    /// left, the percent in the empty part.
    enum Mark {
        static let width: CGFloat = 84
        static let height: CGFloat = 38
        static let stroke: CGFloat = 2
        static let radius: CGFloat = 10
        static let inset: CGFloat = 5
        static let chargeRadius: CGFloat = 5
        static let minCharge: CGFloat = 7
        /// The charge never takes more than this share of the inside, so the percent always has room.
        static let maxChargeShare: CGFloat = 0.35
        static let percent: CGFloat = 15
        static let capWidth: CGFloat = 3.5
        static let capHeight: CGFloat = 13
        static let capGap: CGFloat = 3
    }

    static let calm = Animation.spring(response: 0.35, dampingFraction: 0.85)
}

/// The one headline on the screen: bold, lowercase, ending in a period.
struct InkHeadline: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: Theme.Size.headline, weight: .bold))
            .tracking(-Theme.Size.headline * 0.025)
            .foregroundStyle(Theme.ink)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
    }
}
