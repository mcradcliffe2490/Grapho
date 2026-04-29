import SwiftUI

/// Grid of chapter buttons for a single book. Tapping a chapter pushes a
/// `ChapterRoute` onto the navigation stack.
struct ChapterSelectorView: View {
    @Environment(BibleStore.self) private var bibleStore
    let book: Book

    private let columns = [GridItem(.adaptive(minimum: 64, maximum: 88), spacing: 12)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(chapterNumbers, id: \.self) { number in
                    NavigationLink(value: ChapterRoute(book: book, chapter: number)) {
                        ChapterTile(number: number)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(24)
        }
        .background(AppColor.background.ignoresSafeArea())
        .navigationTitle(book.displayName)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var chapterNumbers: [Int] {
        guard let bibleBook = bibleStore.translation?.book(book) else { return [] }
        return bibleBook.orderedChapters.map { $0.number }
    }
}

private struct ChapterTile: View {
    let number: Int

    var body: some View {
        Text("\(number)")
            .font(.title3.weight(.medium))
            .foregroundStyle(AppColor.textPrimary)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(AppColor.surface)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(AppColor.border, lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
