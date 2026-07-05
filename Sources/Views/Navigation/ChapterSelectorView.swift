import SwiftUI

/// Chapter grid for one book. Layout matches the Figma: a tight grid of
/// soft-rounded squares with serif numerals, and a "< Books  Genesis"
/// header at the top-left where the book name reads as the page title in
/// the body serif.
struct ChapterSelectorView: View {
    @Environment(BibleStore.self) private var bibleStore
    @Environment(\.dismiss) private var dismiss
    @AppStorage(PreferenceKey.backgroundPalette) private var paletteRaw: String = BackgroundPalette.default.rawValue
    private var palette: BackgroundPalette { .current(rawValue: paletteRaw) }

    let book: Book

    private let columns = [GridItem(.adaptive(minimum: 64, maximum: 80), spacing: 14)]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
                .padding(.top, 16)

            ScrollView {
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(chapterNumbers, id: \.self) { number in
                        NavigationLink(value: ChapterRoute(book: book, chapter: number)) {
                            ChapterTile(number: number)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 48)
                .padding(.vertical, 32)
                .frame(maxWidth: 720, alignment: .center)
                .frame(maxWidth: .infinity)
            }
        }
        .background(palette.color.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            Button {
                dismiss()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .medium))
                    Text("Books")
                        .font(AppFont.uiBody)
                }
                .foregroundStyle(AppColor.textSecondary)
            }
            .buttonStyle(.plain)

            Text(book.displayName)
                .font(.custom("CrimsonText-Regular", size: 22, relativeTo: .title))
                .foregroundStyle(AppColor.textPrimary)
            Spacer()
        }
        .padding(.horizontal, 32)
        .padding(.top, 24)
    }

    private var chapterNumbers: [Int] {
        guard let bibleBook = bibleStore.translation?.book(book) else { return [] }
        return bibleBook.orderedChapters.map { $0.number }
    }
}

/// Soft-rounded chapter tile. Light-gray fill, serif numeral, no border —
/// the fill carries enough contrast against the off-white background.
private struct ChapterTile: View {
    let number: Int

    var body: some View {
        Text("\(number)")
            .font(AppFont.chapterTileNumber)
            .foregroundStyle(AppColor.textPrimary)
            .frame(width: 60, height: 60)
            .background(AppColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
