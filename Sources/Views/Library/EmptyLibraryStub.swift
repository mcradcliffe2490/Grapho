import SwiftUI

/// Shared empty-state for library/secondary nav screens that don't have content
/// yet. Lifted into its own type so all four placeholders read identically and
/// the real implementations replace just the body, not the chrome.
struct EmptyLibraryStub: View {
    let title: String
    let message: String

    var body: some View {
        ZStack {
            AppColor.background.ignoresSafeArea()
            VStack(spacing: 12) {
                Text(title.uppercased())
                    .font(AppFont.stickyTitle)
                    .foregroundStyle(AppColor.textSecondary)
                Text(message)
                    .font(.callout)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(AppColor.textFaint)
                    .padding(.horizontal, 48)
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
