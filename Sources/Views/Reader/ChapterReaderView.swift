import SwiftUI
import SwiftData

/// The Phase 4 reader. Renders a chapter with sticky title, optional Psalm
/// superscription, and the verse body. Records a `ChapterVisit` and persists
/// the last-read position whenever the route changes so "Continue Reading"
/// on Home reflects reality.
///
/// Prose books flow as a single continuous block (verse numbers inline);
/// poetic books render each verse as a separate paragraph with extra
/// spacing. No line-indentation in v1 — the source JSON doesn't carry it.
///
/// Chapter advance is wired through a closure the parent supplies so that
/// "next chapter" replaces (not appends) the top of the navigation stack —
/// sequential reading shouldn't accumulate a back-stack of every chapter.
/// Pull-to-advance with crossfade is deferred to Phase 5; v1 ships with an
/// explicit footer button.
struct ChapterReaderView: View {
    @Environment(BibleStore.self) private var bibleStore
    @Environment(\.modelContext) private var modelContext

    let route: ChapterRoute
    /// Replaces the current top of the navigation stack with the new route.
    /// Supplied by `ContentView` so the reader stays decoupled from
    /// `NavigationPath` plumbing.
    let advance: (ChapterRoute) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                StickyTitleView(book: route.book, chapter: route.chapter)

                if let chapter = chapter {
                    if let superscription = chapter.superscription {
                        Text(superscription)
                            .font(AppFont.superscription)
                            .foregroundStyle(AppColor.textFaint)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.bottom, 16)
                    }

                    chapterBody(chapter)

                    chapterFooter
                } else {
                    Text("Chapter not available in this translation.")
                        .foregroundStyle(AppColor.textFaint)
                        .padding(.top, 32)
                }
            }
            .padding(.leading, AppSpacing.readingMarginLeading)
            .padding(.trailing, AppSpacing.readingMarginTrailing)
            .padding(.top, AppSpacing.chapterTopPadding)
            .padding(.bottom, 96)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(AppColor.background.ignoresSafeArea())
        .navigationTitle("\(route.book.displayName) \(route.chapter)")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: routeKey) {
            // Re-runs whenever route changes — covers both first-appearance
            // and chapter-advance.
            await onChapterAppear()
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private func chapterBody(_ chapter: BibleChapter) -> some View {
        if route.book.isPoetic {
            VStack(alignment: .leading, spacing: AppSpacing.verseSpacingPoetic + 6) {
                ForEach(chapter.verses) { verse in
                    VerseView(verse: verse, isPoetic: true)
                }
            }
        } else {
            // Prose: concatenate into a single Text so verse numbers wrap
            // inline with the surrounding sentence rather than starting a
            // new line. AttributedString handles per-run styling.
            Text(prosePassage(verses: chapter.verses))
                .lineSpacing(AppSpacing.scriptureLineSpacing)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var chapterFooter: some View {
        VStack(spacing: 12) {
            Divider()
                .padding(.vertical, 32)
            if let next = navigator?.next(after: route) {
                Button {
                    advance(next)
                } label: {
                    HStack(spacing: 6) {
                        Text("\(next.book.displayName) \(next.chapter)")
                        Image(systemName: "chevron.right")
                    }
                    .font(.callout.weight(.medium))
                    .foregroundStyle(AppColor.textPrimary)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(AppColor.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(AppColor.border, lineWidth: 0.5)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            } else {
                Text("End of canon.")
                    .font(.footnote)
                    .foregroundStyle(AppColor.textFaint)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Helpers

    private var chapter: BibleChapter? {
        bibleStore.translation?.chapter(book: route.book, number: route.chapter)
    }

    private var navigator: ChapterNavigator? {
        bibleStore.translation.map(ChapterNavigator.init)
    }

    /// Identifier the `.task(id:)` modifier observes — one string per
    /// (book, chapter) so we re-log on each chapter change.
    private var routeKey: String {
        "\(route.book.rawValue)-\(route.chapter)"
    }

    private func onChapterAppear() async {
        guard let translationId = bibleStore.translation?.identifier else { return }
        let store = AnnotationStore(context: modelContext)
        store.recordVisit(translation: translationId, book: route.book, chapter: route.chapter)
        try? store.save()
        LastReadingPosition(book: route.book, chapter: route.chapter).save()
    }

    /// Build a single AttributedString that interleaves a small superscript
    /// verse number and the verse text, separated by a single space.
    private func prosePassage(verses: [BibleVerse]) -> AttributedString {
        var out = AttributedString("")
        var bodyAttrs = AttributeContainer()
        bodyAttrs.font = AppFont.scriptureBody
        bodyAttrs.foregroundColor = AppColor.textPrimary

        var numAttrs = AttributeContainer()
        numAttrs.font = AppFont.verseNumber
        numAttrs.foregroundColor = AppColor.textFaint
        numAttrs.baselineOffset = 4

        for (index, verse) in verses.enumerated() {
            if index > 0 {
                out += AttributedString(" ", attributes: bodyAttrs)
            }
            out += AttributedString("\(verse.number) ", attributes: numAttrs)
            out += AttributedString(verse.text, attributes: bodyAttrs)
        }
        return out
    }
}
