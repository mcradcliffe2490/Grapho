import SwiftUI

/// Compact chapter title shown above the verses. The design calls for a
/// sticky bar that fades as the user scrolls past it; for v1 we render a
/// simple inline title and let the navigation bar carry the always-visible
/// label. Fade-on-scroll is Phase 5 polish.
struct StickyTitleView: View {
    let book: Book
    let chapter: Int

    var body: some View {
        VStack(spacing: 4) {
            Text(book.displayName.uppercased())
                .font(AppFont.sectionHeader)
                .foregroundStyle(AppColor.textSecondary)
                .tracking(1.5)
            Text("Chapter \(chapter)")
                .font(AppFont.stickyTitle)
                .foregroundStyle(AppColor.textFaint)
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 24)
    }
}
