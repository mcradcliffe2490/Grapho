import SwiftUI

/// Left-side floating "library" bubble in the reader. Sits in the screen's
/// left margin, fixed in screen space. Tap → popover drawer with:
///
/// 1. Home — pops the stack to the landing screen.
/// 2. Books — list of all canonical books for one-tap jumps; selecting a
///    book replaces the stack with `[book]` so the user lands directly on
///    that book's chapter selector.
/// 3. Notes — pushes the full-screen notes browser.
///
/// Post-MVP candidates listed in the design conversation (daily lectionary,
/// reflections) intentionally not added yet — keeping v1 shallow.
struct LibraryMenuButton: View {
    let navigation: ReaderNavigation
    @Environment(BibleStore.self) private var bibleStore

    @State private var open = false

    var body: some View {
        Button {
            open.toggle()
        } label: {
            Image(systemName: "books.vertical")
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(AppColor.textSecondary)
                .frame(width: 36, height: 36)
                .background(AppColor.background)
                .overlay(Circle().strokeBorder(AppColor.border, lineWidth: 0.75))
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 1)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Library")
        .popover(isPresented: $open, arrowEdge: .leading) {
            drawer
                .presentationCompactAdaptation(.popover)
        }
    }

    private var drawer: some View {
        VStack(spacing: 0) {
            // Top quick-actions
            quickActionRow(label: "Home", icon: "house") {
                navigation.goHome()
                open = false
            }
            Divider()
            quickActionRow(label: "Notes", icon: "note.text") {
                navigation.openNotesBrowser()
                open = false
            }
            Divider()
            // Books — collapsible list. We let it scroll inside the popover
            // so all 66 books are reachable without navigating away first.
            booksSection
        }
        .frame(width: 280)
        .frame(maxHeight: 520)
    }

    private func quickActionRow(label: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .frame(width: 18)
                Text(label)
                    .font(AppFont.uiBody)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11))
                    .foregroundStyle(AppColor.textFaint)
            }
            .foregroundStyle(AppColor.textPrimary)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }

    private var booksSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("BOOKS")
                    .font(AppFont.microCaps)
                    .tracking(AppSpacing.smallCapsTracking)
                    .foregroundStyle(AppColor.textFaint)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 6)

            ScrollView {
                LazyVStack(spacing: 0) {
                    bookGroup(title: "Old Testament", books: Book.oldTestament)
                    bookGroup(title: "New Testament", books: Book.newTestament)
                }
            }
        }
    }

    @ViewBuilder
    private func bookGroup(title: String, books: [Book]) -> some View {
        Text(title.uppercased())
            .font(.caption2)
            .tracking(1.2)
            .foregroundStyle(AppColor.textFaint)
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 4)
            .frame(maxWidth: .infinity, alignment: .leading)

        ForEach(books) { book in
            Button {
                navigation.openBook(book)
                open = false
            } label: {
                HStack {
                    Text(book.displayName)
                        .font(AppFont.bookListName)
                        .foregroundStyle(isAvailable(book) ? AppColor.textPrimary : AppColor.textFaint)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
            }
            .buttonStyle(.plain)
            .disabled(!isAvailable(book))
        }
    }

    private func isAvailable(_ book: Book) -> Bool {
        bibleStore.translation?.book(book) != nil
    }
}
