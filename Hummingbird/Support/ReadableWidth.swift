import SwiftUI

/// Layout constants shared across the app.
enum Layout {
    /// The widest a column of primary content is allowed to get. On a 13" iPad
    /// the phone layout would otherwise stretch cards to ~1000pt and read as a
    /// blown-up phone screen; capping to a comfortable measure and centering
    /// makes it a considered iPad app instead. Tuned a little wider than a pure
    /// text measure because Hummingbird's cards carry charts and side-by-side
    /// stats.
    static let readableContentWidth: CGFloat = 620
}

extension View {
    /// Constrain content to `Layout.readableContentWidth`, centered, but ONLY on
    /// a regular horizontal size class (iPad — and, in theory, iPhone landscape,
    /// which this portrait-locked app never hits). On compact (every iPhone in
    /// portrait) it is a no-op, so the iPhone layout is byte-for-byte unchanged.
    ///
    /// Works on both a `ScrollView`'s content and a `List`: capping a List's
    /// width narrows and centers the inset-grouped column, and `fillColor`
    /// paints the gutters either side so the page still reads as one surface.
    /// Pass `fillColor: nil` when an outer view already paints the full width.
    func readableContentWidth(
        _ maxWidth: CGFloat = Layout.readableContentWidth,
        fillColor: Color? = Color(.systemGroupedBackground)
    ) -> some View {
        modifier(ReadableContentWidth(maxWidth: maxWidth, fillColor: fillColor))
    }
}

private struct ReadableContentWidth: ViewModifier {
    let maxWidth: CGFloat
    let fillColor: Color?
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    func body(content: Content) -> some View {
        if horizontalSizeClass == .regular {
            content
                .frame(maxWidth: maxWidth)
                .frame(maxWidth: .infinity)
                .background(alignment: .center) {
                    if let fillColor {
                        fillColor.ignoresSafeArea()
                    }
                }
        } else {
            content
        }
    }
}
